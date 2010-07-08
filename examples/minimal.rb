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

class User < Swift::Model.schema do
    property :id,    Integer
    property :name,  String
    property :email, String
  end
end # User

db = Swift::Adapter.new(user: Etc.getlogin, driver: 'postgresql', db: 'swift')
Swift.setup :default, DebugAdapter.new(db)

Swift.db.prepare(User, 'select * from users').execute.each{|a| }
# Swift.db.prepare(User, "select * from #{User.resource} where #{User.id.field} = ?").execute(1) {|r| p r }
