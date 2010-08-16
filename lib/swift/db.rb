module Swift
  module DB
    class Mysql < Adapter
      def initialize options = {}
        super options.update(driver: 'mysql')
        sync_timezone
      end

      def timezone *args
        super(*args)
        sync_timezone
        @tzoffset
      end

      def returning?
        false
      end

      private
      def sync_timezone
        execute('select unix_timestamp() - unix_timestamp(utc_timestamp()) as offset') {|r| @tzoffset = r[:offset] }
      end
    end # Mysql

    class Postgres < Adapter
      def initialize options = {}
        super options.update(driver: 'postgresql')
        sync_timezone
      end

      def timezone *args
        super(*args)
        sync_timezone
        @tzoffset
      end

      def returning?
        true
      end

      def field_definition attribute
        case attribute
          when Type::IO then '%s bytea' % attribute.field
          else super
        end
      end

      private
      def sync_timezone
        sql = "select extract(epoch from now())::bigint - extract(epoch from now() at time zone 'UTC')::bigint"
        execute('%s as offset' % sql) {|r| @tzoffset = r[:offset] }
      end
    end # Postgres
  end # DB
end # Swift
