module Swift
  class Migrations
    def initialize adapter
      @adapter = adapter.kind_of?(Adapter) ? adapter : Swift.db(adapter)
    end

    def typemap
      { Integer => 'integer', String => 'text', Float => 'float', Time => 'timestamp', serial: 'serial' }
    end

    def migrate_up! model
      fields = model.properties.map {|p| column_definition(p) }.join(', ')
      @adapter.execute "create table #{model.resource} (#{fields})"
    end

    def column_definition property
      "#{property.field} #{property.serial ? typemap[:serial] : typemap[property.type] || 'text'}"
    end

    def migrate_down! model
      @adapter.execute "drop table if exists #{model.resource}"
    end

    def migrate! model
      migrate_down! model
      migrate_up!   model
    end

    class MySQL < self
      def typemap
        super.merge({Time => 'datetime', String => 'varchar(255)'})
      end
    end

    class PostgreSQL < self; end
  end

  def self.auto_migrate! scope=:default
    adapter = Swift.db(scope)
    case adapter.driver.to_sym
      when :mysql
        migrator = Swift::Migrations::MySQL.new(adapter)
        Swift::Model.models.each {|m| migrator.migrate!(m) }
      when :postgresql
        migrator = Swift::Migrations::PostgreSQL.new(adapter)
        Swift::Model.models.each {|m| migrator.migrate!(m) }
    end
  end
end
