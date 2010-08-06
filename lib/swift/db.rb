module Swift
  module DB
    class Mysql < Adapter
      def initialize options = {}
        super options.update(driver: 'mysql')
        execute('select unix_timestamp() - unix_timestamp(utc_timestamp()) as offset') {|r| @tzoffset = r[:offset] }
      end

      def timezone *args
        super(*args)
        execute('select unix_timestamp() - unix_timestamp(utc_timestamp()) as offset') {|r| @tzoffset = r[:offset] }
        @tzoffset
      end

      def returning?
        false
      end
    end # Mysql

    class Postgres < Adapter
      def initialize options = {}
        super options.update(driver: 'postgresql')
        sql = "select extract(epoch from now())::bigint - extract(epoch from now() at time zone 'UTC')::bigint"
        execute('%s as offset' % sql) {|r| @tzoffset = r[:offset] }
      end

      def timezone *args
        super(*args)
        sql = "select extract(epoch from now())::bigint - extract(epoch from now() at time zone 'UTC')::bigint"
        execute('%s as offset' % sql) {|r| @tzoffset = r[:offset] }
        @tzoffset
      end

      def returning?
        true
      end
    end # Postgres
  end # DB
end # Swift
