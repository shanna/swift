module Swift
  module Migrations
    module ClassMethods
      def migrations &migrations
        define_singleton_method(:migrate!, lambda{|db = Swift.db| migrations.call(db)})
      end

      def migrate! db = Swift.db
        db.migrate! self
      end
    end # ClassMethods

    module InstanceMethods
      def migrate! scheme
        keys   =  scheme.header.keys
        fields =  scheme.header.map{|p| field_definition(p)}.join(', ')
        fields += ", primary key (#{keys.join(', ')})" unless keys.empty?

        execute("drop table if exists #{scheme.store} cascade")
        execute("create table #{scheme.store} (#{fields})")
      end
    end # InstanceMethods
  end # Migrations

  def self.migrate! name = nil
    schema.each{|scheme| scheme.migrate!(db(name)) }
  end

  class Adapter::Sql
    extend  Migrations::ClassMethods
    include Migrations::InstanceMethods
  end
end # Swift
