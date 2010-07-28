module Swift
  #--
  # TODO: Driver specific subclasses and factory.
  class Adapter < DBI::Handle
    attr_reader :options

    def identity_map
      @identity_map ||= IdentityMap.new
    end

    def prepare scheme, query = nil
      return super(scheme) unless scheme.kind_of?(Class) && scheme < Scheme
      Statement.new(self, scheme, query)
    end

    def get scheme, keys
      relation = scheme.new(keys)
      prepare_get(scheme).execute(*relation.tuple.values_at(*scheme.attributes.keys)).first
    end

    def create scheme, *relations
      statement = prepare_create(scheme)
      relations.map do |relation|
        relation = scheme.new(relation) unless relation.kind_of?(scheme)
        if statement.execute(*relation.tuple.values_at(*scheme.attributes.insertable)) && scheme.attributes.serial
          relation.tuple[scheme.attributes.serial] = statement.insert_id
        end
        relation
      end
    end

    def update scheme, *relations
      statement = prepare_update(scheme)
      relations.map do |relation|
        relation = scheme.new(relation) unless relation.kind_of?(scheme)
        statement.execute(*relation.tuple.values_at(*scheme.attributes.updatable, *scheme.attributes.keys))
      end
    end

    def destroy scheme, *relations
      statement = prepare_destroy(scheme)
      relations.map do |relation|
        relation = scheme.new(relation) unless relation.kind_of?(scheme)
        if result = statement.execute(*relation.tuple.values_at(*scheme.attributes.keys))
          relation.freeze
        end
        result
      end
    end

    def transaction name = nil, &block
      super(name){ self.instance_eval(&block)}
    end

    def driver
      @options[:driver]
    end

    def migrate! scheme
      keys   =  scheme.attributes.keys
      fields =  scheme.attributes.map{|p| field_definition(p)}.join(', ')
      fields += ", primary key (#{keys.join(', ')})" unless keys.empty?

      execute("drop table if exists #{scheme.store}")
      execute("create table #{scheme.store} (#{fields})")
    end

    protected
      def returning?
        @returning ||= !!(driver == 'postgresql')
      end

      def prepare_cached scheme, name, &block
        @prepared              ||= Hash.new{|h,k| h[k] = Hash.new} # Autovivification please Matz!
        @prepared[scheme][name] ||= prepare(scheme, yield)
      end

      def prepare_get scheme
        prepare_cached(scheme, :get) do
          where = scheme.attributes.keys.map{|key| "#{key} = ?"}.join(' and ')
          "select * from #{scheme.store} where #{where} limit 1"
        end
      end

      def prepare_create scheme
        prepare_cached(scheme, :create) do
          values    = (['?'] * scheme.attributes.insertable.size).join(', ')
          returning = "returning #{scheme.attributes.serial}" if scheme.attributes.serial and returning?
          "insert into #{scheme.store} (#{scheme.attributes.insertable.join(', ')}) values (#{values}) #{returning}"
        end
      end

      def prepare_update scheme
        prepare_cached(scheme, :update) do
          set   = scheme.attributes.updatable.map{|field| "#{field} = ?"}.join(', ')
          where = scheme.attributes.keys.map{|key| "#{key} = ?"}.join(' and ')
          "update #{scheme.store} set #{set} where #{where}"
        end
      end

      def prepare_destroy scheme
        prepare_cached(scheme, :destroy) do
          where = scheme.attributes.keys.map{|key| "#{key} = ?"}.join(' and ')
          "delete from #{scheme.store} where #{where}"
        end
      end

      def field_definition attribute
        "#{attribute.field} " + case attribute
          when Type::String     then 'text'
          when Type::Integer    then attribute.serial ? 'serial' : 'integer'
          when Type::Float      then 'float'
          when Type::BigDecimal then 'numeric'
          when Type::Time       then 'timestamp'
          when Type::Boolean    then 'boolean'
          else 'text'
        end
      end
  end # Adapter
end # Swift
