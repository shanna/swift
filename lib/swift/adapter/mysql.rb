require 'swift/db/mysql'
require 'swift/adapter/sql'

module Swift
  class Adapter
    class Mysql < Sql
      def initialize options = {}
        super Swift::DB::Mysql.new(options)
      end

      def returning?
        false
      end

      # TODO Swift::Type::Bignum ?
      # serial is an alias for bigint in mysql, we want integer type to be migrated as integer
      # type in the database (not bigint or smallint or shortint or whatever).
      def field_type attribute
        case attribute
          when Type::Integer then attribute.serial ? 'integer auto_increment' : 'integer'
          else super
        end
      end

      def tables
        execute("show tables").map(&:values).flatten
      end
    end # Mysql
  end # Adapter
end # Swift
