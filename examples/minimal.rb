#!/usr/bin/env ruby
require_relative '../lib/swift'
require 'etc'
require 'pp'

require 'delegate'
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

Swift.setup user: Etc.getlogin, driver: 'postgresql', db: 'swift'
Swift.db do
  prepare(User, 'select * from users').execute.each do |a|
    pp a
  end
end
# Swift.db.prepare(User, "select * from #{User.resource} where #{User.id.field} = ?").execute(1) {|r| p r }
