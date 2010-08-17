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

      def field_definition attribute
        case attribute
          when Type::IO then '%s bytea' % attribute.field
          else super
        end
      end
    end # Postgres
  end # DB
end # Swift
