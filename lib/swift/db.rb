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

    class DB2 < Adapter
      def initialize options = {}
        super options.update(driver: 'db2')
      end

      def returning?
        false
      end

      def drop_store name
        exists_sql =<<-SQL
          select count(*) as exists from syscat.tables where tabschema = CURRENT_SCHEMA and tabname = '#{name.upcase}'
        SQL

        execute(exists_sql.strip) do |r|
          execute("drop table #{name}") if r[:exists] > 0
        end
      end

      def field_type attribute
        case attribute
          when Type::String     then 'clob(2g)'
          when Type::Integer    then attribute.serial ? 'integer generated always as identity' : 'integer'
          when Type::Boolean    then 'char(1)'
          when Type::Float      then 'real'
          when Type::BigDecimal then 'double'
          else super
        end
      end

      def prepare_create scheme
        prepare_cached(scheme, :create) do
          values = (['?'] * scheme.header.insertable.size).join(', ')
          sql    = "insert into #{scheme.store} (#{scheme.header.insertable.join(', ')}) values (#{values})"
          scheme.header.serial ? "select #{scheme.header.serial} from final table (#{sql})" : sql
        end
      end
    end # DB2
  end # DB
end # Swift
