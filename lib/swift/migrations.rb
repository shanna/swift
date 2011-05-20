module Swift
  module Migrations
    module ClassMethods
      # @example
      #   class User < Swift::Scheme
      #     migrations do |db|
      #       db.execute %q{create table users(id serial, name text, age int)}
      #     end
      #   end
      #
      # @param [Proc] &migrations
      #
      # @see Swift::Scheme
      def migrations &migrations
        define_singleton_method(:migrate!, lambda{|db = Swift.db| migrations.call(db)})
      end

      # @example
      #   User.migrate!
      #
      # @param [Swift::Adapter] db
      #
      # @see Swift::Scheme
      def migrate! db = Swift.db
        db.migrate! self
      end
    end # ClassMethods

    module InstanceMethods
      # @example
      #   db.migrate! User
      #
      # @param [Swift::Scheme] scheme
      #
      # @see Swift::Adapter::Sql
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

  class Scheme
    extend Migrations::ClassMethods
  end

  class Adapter::Sql
    include Migrations::InstanceMethods
  end
end # Swift
