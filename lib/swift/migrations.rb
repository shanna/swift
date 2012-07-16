module Swift
  module Migrations
    module ClassMethods
      # @example
      #   class User < Swift::Record
      #     migrations do |db|
      #       db.execute %q{create table users(id serial, name text, age int)}
      #     end
      #   end
      #
      # @param [Proc] &migrations
      #
      # @see Swift::Record
      def migrations &migrations
        define_singleton_method(:migrate!, lambda{|db = Swift.db| migrations.call(db)})
      end

      # @example
      #   User.migrate!
      #
      # @param [Swift::Adapter] db
      #
      # @see Swift::Record
      def migrate! db = Swift.db
        db.migrate! self
      end
    end # ClassMethods

    module InstanceMethods
      # @example
      #   db.migrate! User
      #
      # @param [Swift::Record] record
      #
      # @see Swift::Adapter::Sql
      def migrate! record
        keys   =  record.header.keys
        fields =  record.header.map{|p| field_definition(p)}.join(', ')
        fields += ", primary key (#{keys.join(', ')})" unless keys.empty?

        execute("drop table if exists #{record.store} cascade")
        execute("create table #{record.store} (#{fields})")
      end
    end # InstanceMethods
  end # Migrations

  def self.migrate! name = nil
    schema.each{|record| record.migrate!(db(name)) }
  end

  class Record
    extend Migrations::ClassMethods
  end

  class Adapter::Sql
    include Migrations::InstanceMethods
  end
end # Swift
