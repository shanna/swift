require 'swift/adapter'

module Swift
  class Adapter

    # Abstract SQL Adapter.
    #
    # @abstract
    class Sql < Adapter
      #--
      # TODO: If we could mixin migrations that'd be swell.
      def migrate! scheme
        keys   =  scheme.header.keys
        fields =  scheme.header.map{|p| field_definition(p)}.join(', ')
        fields += ", primary key (#{keys.join(', ')})" unless keys.empty?

        execute("drop table if exists #{scheme.store} cascade")
        execute("create table #{scheme.store} (#{fields})")
      end

      protected
        def returning?
          raise NotImplementedError
        end

        def prepare_cached scheme, name, &block
          @prepared               ||= Hash.new{|h,k| h[k] = Hash.new}
          @prepared[scheme][name] ||= prepare(scheme, yield)
        end

        #--
        # TODO: Complain if parts of the primary key are missing.
        def prepare_get scheme
          prepare_cached(scheme, :get) do
            where = scheme.header.keys.map{|key| "#{key} = ?"}.join(' and ')
            "select * from #{scheme.store} where #{where} limit 1"
          end
        end

        def prepare_all scheme, statement = ''
          statement = "select * from #{scheme.store}" if statement.empty?
          prepare(scheme, statement)
        end

        def prepare_first scheme, statement = ''
          statement = "select * from #{scheme.store} limit 1" if statement.empty?
          prepare(scheme, statement)
        end

        def prepare_delete scheme, statement = ''
          statement = "delete from #{scheme.store}" if statement.empty?
          prepare(scheme, statement)
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
          "#{attribute.field} " + field_type(attribute)
        end

        def field_type attribute
          case attribute
            when Type::String     then 'text'
            when Type::Integer    then attribute.serial ? 'serial' : 'integer'
            when Type::Float      then 'float'
            when Type::BigDecimal then 'numeric'
            when Type::Time       then 'timestamp'
            when Type::Date       then 'date'
            when Type::Boolean    then 'boolean'
            when Type::IO         then 'blob'
            else 'text'
          end
        end
    end # Sql
  end # Adapter
end # Swift
