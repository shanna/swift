#!/usr/bin/env ruby
require_relative '../lib/swift'
require 'delegate'
require 'etc'
require 'pp'

class DebugAdapter < DelegateClass(Swift::Adapter)
  [:prepare, :execute, :get, :transaction].each do |sub|
    define_method(sub) do |*args, &block|
      pp [sub, args, (block_given? ? '&block' : nil)].compact
      super *args, &block
    end
  end
end

class User < Swift::Model.meta do
    property :name, String
    property :age,  Integer
  end
end # User

# db1 = Swift::DBI::Handle.new(user: Etc.getlogin, driver: 'postgresql', db: 'swift')
# db1.prepare('select * from users').execute

db = Swift::Adapter.new(user: Etc.getlogin, driver: 'postgresql', db: 'swift')
Swift.setup :default, db
# Swift.setup :default, DebugAdapter.new(db)

Swift.db.prepare('select * from users').execute
# Swift.db.prepare(User, 'select * from users').execute
