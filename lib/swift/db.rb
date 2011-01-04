module Swift
  module DB
    class Mysql < Adapter
      def initialize options = {}
        super options.update(driver: 'mysql')
      end

      def returning?
        false
      end
    end # Mysql

    class Sqlite3 < Adapter
      def initialize options = {}
        super options.update(driver: 'sqlite3')
      end

      def returning?
        false
      end

      def field_type attribute
        case attribute
          when Type::String     then 'text'
          when Type::Integer    then attribute.serial ? 'integer primary key' : 'integer'
          when Type::Float      then 'float'
          when Type::BigDecimal then 'numeric'
          when Type::Time       then 'text'
          when Type::Date       then 'text'
          when Type::Boolean    then 'integer'
          when Type::IO         then 'blob'
          else 'text'
        end
      end
    end # Sqlite3

    class Postgres < Adapter
      def initialize options = {}
        super options.update(driver: 'postgresql')
      end

      def returning?
        true
      end

      def field_type attribute
        case attribute
          when Type::IO then 'bytea'
          else super
        end
      end
    end # Postgres
  end # DB
end # Swift
