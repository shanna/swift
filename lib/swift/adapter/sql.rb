require 'swift/adapter'

module Swift
  class Adapter

    # Abstract SQL Adapter.
    #
    # @abstract
    class Sql < Adapter
      attr_reader :prepare_sql

      def initialize options
        @prepare_sql = options.key?(:prepare_sql) ? options.delete(:prepare_sql) : true
        super(options)
      end

      def tables
        raise NotImplementedError
      end

      def fields table
        result = execute("select * from #{table} limit 0")
        Hash[result.fields.map(&:to_sym).zip(result.field_types)]
      end

      def clear_prepared_cache
        @prepared = Hash.new{|h,k| h[k] = Hash.new}
      end

      # Send SQL without prepared statements, defered till execute() is called.
      #
      # @private
      class Defer
        def initialize adapter, scheme, sql
          @adapter = adapter
          @scheme  = scheme
          @sql     = sql
        end

        def execute *args
          @adapter.execute(@scheme, @sql, *args)
        end
      end

      protected
        def returning?
          raise NotImplementedError
        end

        def prepare_cached scheme, name, &block
          @prepared               ||= Hash.new{|h,k| h[k] = Hash.new}
          @prepared[scheme][name] ||= prepare_sql ? prepare(scheme, yield) : Defer.new(self, scheme, yield)
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

        def prepare_delete scheme
          prepare_cached(scheme, :delete) do
            where = scheme.header.keys.map{|key| "#{key} = ?"}.join(' and ')
            "delete from #{scheme.store} where #{where}"
          end
        end

        def field_definition attribute
          "#{attribute.field} " + field_type(attribute)
        end

        def field_type attribute
          case attribute
            when Type::String     then 'text'
            when Type::Integer    then attribute.serial ? 'serial' : 'integer'
            when Type::Float      then 'float'
            when Type::BigDecimal then 'numeric'
            when Type::Time       then 'timestamp' # deprecated
            when Type::DateTime   then 'timestamp'
            when Type::Date       then 'date'
            when Type::Boolean    then 'boolean'
            when Type::IO         then 'blob'
            else 'text'
          end
        end
    end # Sql
  end # Adapter
end # Swift
