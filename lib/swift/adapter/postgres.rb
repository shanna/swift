require 'swift/db/postgres'
require 'swift/adapter/sql'

module Swift
  class Adapter
    class Postgres < Sql
      def initialize options = {}
        super Swift::DB::Postgres.new(options)
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

      def tables
        execute('select tablename from pg_tables where schemaname = current_schema').map(&:values).flatten
      end
    end # Postgres
  end # Adapter
end # Swift
