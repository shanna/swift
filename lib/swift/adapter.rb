module Swift
  #--
  # TODO: Driver specific subclasses and factory.
  class Adapter < DBI::Handle
    attr_reader :options

    def identity_map
      @identity_map ||= IdentityMap.new
    end

    def prepare model, query = nil
      return super(model) unless model.kind_of?(Class) && model < Resource
      Statement.new(self, model, query)
    end

    def get model, keys
      resource = model.new(keys)
      prepare_get(model).execute(*resource.tuple.values_at(*model.attributes.keys)).first
    end

    def create model, *resources
      statement = prepare_create(model)
      resources.map do |resource|
        resource = model.new(resource) unless resource.kind_of?(model)
        if statement.execute(*resource.tuple.values_at(*model.attributes.insertable)) && model.attributes.serial?
          resource.tuple[model.attributes.serial] = statement.insert_id
        end
        resource
      end
    end

    def update model, *resources
      statement = prepare_update(model)
      resources.map do |resource|
        resource = model.new(resource) unless resource.kind_of?(model)
        statement.execute(*resource.tuple.values_at(*model.attributes.updatable, *model.attributes.keys))
      end
    end

    def transaction name = nil, &block
      super(name){ self.instance_eval(&block)}
    end

    def driver
      @options[:driver]
    end

    def migrate! model
      keys   =  model.attributes.keys
      fields =  model.attributes.map{|p| field_definition(p)}.join(', ')
      fields += ", primary key (#{keys.join(', ')})" unless keys.empty?

      execute("drop table if exists #{model.store}")
      execute("create table #{model.store} (#{fields})")
    end

    protected
      def returning?
        @returning ||= !!(driver == 'postgresql')
      end

      def prepare_cached model, name, &block
        @prepared              ||= Hash.new{|h,k| h[k] = Hash.new} # Autovivification please Matz!
        @prepared[model][name] ||= prepare(model, yield)
      end

      def prepare_get model
        prepare_cached(model, :get) do
          where = model.attributes.keys.map{|key| "#{key} = ?"}.join(' and ')
          "select * from #{model.store} where #{where} limit 1"
        end
      end

      def prepare_create model
        prepare_cached(model, :create) do
          values    = (['?'] * model.attributes.insertable.size).join(', ')
          returning = "returning #{model.attributes.serial}" if model.attributes.serial? and returning?
          "insert into #{model.store} (#{model.attributes.insertable.join(', ')}) values (#{values}) #{returning}"
        end
      end

      def prepare_update model
        prepare_cached(model, :update) do
          set   = model.attributes.updatable.map{|field| "#{field} = ?"}.join(', ')
          where = model.attributes.keys.map{|key| "#{key} = ?"}.join(' and ')
          "update #{model.store} set #{set} where #{where}"
        end
      end

      def field_definition attribute
        "#{attribute.field} " + case attribute
          when Attribute::String     then 'text'
          when Attribute::Integer    then attribute.serial? ? 'serial' : 'integer'
          when Attribute::Float      then 'float'
          when Attribute::BigDecimal then 'numeric'
          when Attribute::Time       then 'timestamp'
          when Attribute::Boolean    then 'boolean'
          else 'text'
        end
      end
  end # Adapter
end # Swift
