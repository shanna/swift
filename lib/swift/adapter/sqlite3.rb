require 'swift/db/sqlite3'
require 'swift/adapter/sql'

module Swift
  class Adapter
    class Sqlite3 < Sql
      def initialize options = {}
        super Swift::DB::Sqlite3.new(options)
      end

      def returning?
        false
      end

      def migrate! record
        keys   =  record.header.keys
        serial =  record.header.find(&:serial)
        fields =  record.header.map{|p| field_definition(p)}.join(', ')
        fields += ", primary key (#{keys.join(', ')})" unless serial or keys.empty?

        execute("drop table if exists #{record.store}")
        execute("create table #{record.store} (#{fields})")
      end

      def field_type attribute
        case attribute
          when Type::String     then 'text'
          when Type::Integer    then attribute.serial ? 'integer primary key' : 'integer'
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

      def tables
        execute('select name from sqlite_master where type = ?', 'table').map(&:values).flatten
      end

      def write table, fields = nil, io
        fields    = execute("select * from #{table} limit 0").fields if fields.nil? or fields.empty?
        statement = prepare("insert into #{table}(#{fields.join(',')}) values (%s)" % (['?'] * fields.size).join(','))

        r  = 0
        io = io.read if io.respond_to?(:read)
        io.split(/\n+/).each do |line|
          r += statement.execute(*line.split(/\t/).map {|value| value == '\N' ? nil : value}).affected_rows
        end

        # TODO: a better way to return a pretend result
        Struct.new(:affected_rows).new(r)
      end
    end # Sqlite3
  end # Adapter
end # Swift
