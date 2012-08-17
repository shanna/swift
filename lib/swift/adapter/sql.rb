require 'swift/adapter'
require 'forwardable'

module Swift
  class Adapter
    # Abstract SQL Adapter.
    #
    # @abstract
    class Sql < Adapter
      extend Forwardable
      def_delegators :db, :begin, :commit, :rollback, :ping, :close, :closed?, :escape, :query, :fileno, :result, :write

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

        def command_get record
          where = record.header.keys.map{|key| "#{key} = ?"}.join(' and ')
          "select * from #{record.store} where #{where} limit 1"
        end

        def command_create record
          values    = (['?'] * record.header.insertable.size).join(', ')
          returning = "returning #{record.header.serial}" if record.header.serial and returning?
          "insert into #{record.store} (#{record.header.insertable.join(', ')}) values (#{values}) #{returning}"
        end

        def command_update record
          set   = record.header.updatable.map{|field| "#{field} = ?"}.join(', ')
          where = record.header.keys.map{|key| "#{key} = ?"}.join(' and ')
          "update #{record.store} set #{set} where #{where}"
        end

        def command_delete record
          where = record.header.keys.map{|key| "#{key} = ?"}.join(' and ')
          "delete from #{record.store} where #{where}"
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
