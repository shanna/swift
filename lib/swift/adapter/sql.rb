require 'swift/adapter'
require 'forwardable'

module Swift
  class Adapter
    # Abstract SQL Adapter.
    #
    # @abstract
    class Sql < Adapter
      extend Forwardable
      def_delegators :db, :begin, :commit, :rollback, :close, :closed?

      def tables
        raise NotImplementedError
      end

      def fields table
        result = execute("select * from #{table} limit 0")
        Hash[result.fields.map(&:to_sym).zip(result.types)]
      end

      def transaction *args
        db.transaction(*args) {|db| yield self}
      end

      protected
        def returning?
          raise NotImplementedError
        end

        def command_get scheme
          where = scheme.header.keys.map{|key| "#{key} = ?"}.join(' and ')
          "select * from #{scheme.store} where #{where} limit 1"
        end

        def command_create scheme
          values    = (['?'] * scheme.header.insertable.size).join(', ')
          returning = "returning #{scheme.header.serial}" if scheme.header.serial and returning?
          "insert into #{scheme.store} (#{scheme.header.insertable.join(', ')}) values (#{values}) #{returning}"
        end

        def command_update scheme
          set   = scheme.header.updatable.map{|field| "#{field} = ?"}.join(', ')
          where = scheme.header.keys.map{|key| "#{key} = ?"}.join(' and ')
          "update #{scheme.store} set #{set} where #{where}"
        end

        def command_delete scheme
          where = scheme.header.keys.map{|key| "#{key} = ?"}.join(' and ')
          "delete from #{scheme.store} where #{where}"
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
