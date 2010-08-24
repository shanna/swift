module Swift
  class Adapter
    attr_reader :options

    def get scheme, keys
      relation = scheme.new(keys)
      prepare_get(scheme).execute(*relation.tuple.values_at(*scheme.header.keys)).first
    end

    def all scheme, conditions = '', *binds, &block
      where = "where #{exchange_names(scheme, conditions)}" unless conditions.empty?
      prepare(scheme, "select * from #{scheme.store} #{where}").execute(*binds, &block)
    end

    def first scheme, conditions = '', *binds, &block
      where = "where #{exchange_names(scheme, conditions)} limit 1" unless conditions.empty?
      prepare(scheme, "select * from #{scheme.store} #{where}").execute(*binds, &block).first
    end

    def create scheme, *relations
      statement = prepare_create(scheme)
      relations.map do |relation|
        relation = scheme.new(relation) unless relation.kind_of?(scheme)
        if statement.execute(*relation.tuple.values_at(*scheme.header.insertable)) && scheme.header.serial
          relation.tuple[scheme.header.serial] = statement.insert_id
        end
        relation
      end
    end

    def update scheme, *relations
      statement = prepare_update(scheme)
      relations.map do |relation|
        relation = scheme.new(relation) unless relation.kind_of?(scheme)
        statement.execute(*relation.tuple.values_at(*scheme.header.updatable, *scheme.header.keys))
        relation
      end
    end

    def destroy scheme, *relations
      statement = prepare_destroy(scheme)
      relations.map do |relation|
        relation = scheme.new(relation) unless relation.kind_of?(scheme)
        if result = statement.execute(*relation.tuple.values_at(*scheme.header.keys))
          relation.freeze
        end
        result
      end
    end

    def migrate! scheme
      keys   =  scheme.header.keys
      fields =  scheme.header.map{|p| field_definition(p)}.join(', ')
      fields += ", primary key (#{keys.join(', ')})" unless keys.empty?

      execute("drop table if exists #{scheme.store}")
      execute("create table #{scheme.store} (#{fields})")
    end

    protected
      def exchange_names scheme, query
        query.gsub(/:(\w+)/){ scheme.send($1.to_sym).field }
      end

      def returning?
        raise NotImplementedError
      end

      def prepare_cached scheme, name, &block
        @prepared               ||= Hash.new{|h,k| h[k] = Hash.new} # Autovivification please Matz!
        @prepared[scheme][name] ||= prepare(scheme, yield)
      end

      def prepare_get scheme
        prepare_cached(scheme, :get) do
          where = scheme.header.keys.map{|key| "#{key} = ?"}.join(' and ')
          "select * from #{scheme.store} where #{where} limit 1"
        end
      end

      def prepare_create scheme
        prepare_cached(scheme, :create) do
          values    = (['?'] * scheme.header.insertable.size).join(', ')
          returning = "returning #{scheme.header.serial}" if scheme.header.serial and returning?
          "insert into #{scheme.store} (#{scheme.header.insertable.join(', ')}) values (#{values}) #{returning}"
        end
      end

      def prepare_update scheme
        prepare_cached(scheme, :update) do
          set   = scheme.header.updatable.map{|field| "#{field} = ?"}.join(', ')
          where = scheme.header.keys.map{|key| "#{key} = ?"}.join(' and ')
          "update #{scheme.store} set #{set} where #{where}"
        end
      end

      def prepare_destroy scheme
        prepare_cached(scheme, :destroy) do
          where = scheme.header.keys.map{|key| "#{key} = ?"}.join(' and ')
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
          when Type::IO         then 'blob'
          else 'text'
        end
      end
  end # Adapter
end # Swift
