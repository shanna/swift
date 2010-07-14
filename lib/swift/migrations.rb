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

    class MySQL < Migrations
      def typemap
        super.merge(Time => 'datetime', String => 'varchar(255)')
      end
    end # MySQL

    class PostgreSQL < Migrations
    end # PostgreSQL
  end # Migrations

  def self.auto_migrate! db = :default
    Swift.db(db) do
      migrator = case driver
        when 'mysql'      then Swift::Migrations::MySQL.new(self)
        when 'postgresql' then Swift::Migrations::PostgreSQL.new(self)
        else raise "Unknown driver '#{driver}'."
      end

      Swift.models.each{|m| migrator.migrate!(m)}
    end
  end
end # Swift
