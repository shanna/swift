#!/usr/bin/env ruby
require_relative '../lib/swift'
require 'etc'
require 'pp'

Swift::DBI.trace true

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
    resource :users
    property :id,    Integer, key: true, serial: true
    property :name,  String
    property :email, String
  end
end # User

Swift.setup user: Etc.getlogin, driver: 'postgresql', db: 'swift'
Swift.db do
  execute('drop table if exists users')
  execute('create table users(id serial, name text, email text)');

  create(
    User.new(name: 'Apple Arthurton', email: 'apple@arthurton.local'),
    User.new(name: 'Benny Arthurton', email: 'benny@arthurton.local')
  )

  prepare(User, 'select * from users').execute.each do |a|
    pp a
  end
end
# Swift.db.prepare(User, "select * from #{User.resource} where #{User.id.field} = ?").execute(1) {|r| p r }
