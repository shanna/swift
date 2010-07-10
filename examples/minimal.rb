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
    property :id,    Integer
    property :name,  String
    property :email, String
  end
end # User

Swift.setup user: Etc.getlogin, driver: 'postgresql', db: 'swift'
Swift.db do
  execute('drop table if exists users')
  execute('create table users(id serial, name text, email text)');

  st = prepare('insert into users(name, email) values(?, ?)')
  st.execute('Apple Arthurton', 'apple@example.com')
  st.execute('Benny Arthurton', 'benny@example.com')

  prepare(User, 'select * from users').execute.each do |a|
    pp a
  end
end
# Swift.db.prepare(User, "select * from #{User.resource} where #{User.id.field} = ?").execute(1) {|r| p r }
