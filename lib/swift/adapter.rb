module Swift
  #--
  # TODO: Golf, DRY and cache the SQL stuff.
  class Adapter < DBI::Handle

    # TODO: DBI::Handle should have this stuff.
    attr_reader :options, :driver

    def initialize options = {}
      @driver  = options.fetch(:driver)
      @options = options
      super
    end

    def returning?
      @driver == 'postgresql'
    end
    protected :returning?

    def identity_map
      @identity_map ||= IdentityMap.new
    end

    def prepare model, query = nil
      return super(model) unless model.kind_of?(Class) && model < Resource
      Statement.new(self, model, query)
    end

    def get model, keys
      resource = model.new(keys)
      prepare_get(model).execute(*resource.tuple.values_at(*model.properties.keys)).first
    end

    def create model, *resources
      statement = prepare_create(model)
      resources.map do |resource|
        resource = model.new(resource) unless resource.kind_of?(model)
        if statement.execute(*resource.tuple.values_at(*model.properties.insertable)) && model.properties.serial?
          resource.tuple[model.properties.serial] = statement.insert_id
        end
        resource
      end
    end

    def update model, *resources
      statement = prepare_update(model)
      resources.map do |resource|
        resource = model.new(resource) unless resource.kind_of?(model)
        statement.execute(*resource.tuple.values_at(*model.properties.updatable, *model.properties.keys))
      end
    end

    def transaction name = nil, &block
      super(name){ self.instance_eval(&block)}
    end

    protected
      def prepare_cached model, name, &block
        @prepared              ||= Hash.new{|h,k| h[k] = Hash.new} # Autovivification please Matz!
        @prepared[model][name] ||= prepare(model, yield)
      end

      def prepare_get model
        prepare_cached(model, :get) do
          where = model.properties.keys.map{|key| "#{key} = ?"}.join(' and ')
          "select * from #{model.store} where #{where} limit 1"
        end
      end

      def prepare_create model
        prepare_cached(model, :create) do
          values    = (['?'] * model.properties.insertable.size).join(', ')
          returning = "returning #{model.properties.serial}" if model.properties.serial? and returning?
          "insert into #{model.store} (#{model.properties.insertable.join(', ')}) values (#{values}) #{returning}"
        end
      end

      def prepare_update model
        prepare_cached(model, :update) do
          set   = model.properties.updatable.map{|field| "#{field} = ?"}.join(', ')
          where = model.properties.keys.map{|key| "#{key} = ?"}.join(' and ')
          "update #{model.store} set #{set} where #{where}"
        end
      end
  end # Adapter
end # Swift
