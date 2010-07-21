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

class User < Swift.resource do
    store    :users
    property :id,       Integer, key: true, serial: true
    property :name,     String
    property :email,    String
  end
end # User

Swift.setup user: Etc.getlogin, db: 'swift', driver: ARGV[0] || 'postgresql'
Swift.trace true

Swift.db do
  execute('drop table if exists users')
  execute('create table users(id serial, name text, email text)')

  puts '-- create --'
  create(User,
    {name: 'Apple Arthurton', email: 'apple@arthurton.local'},
    {name: 'Benny Arthurton', email: 'benny@arthurton.local'}
  )

  puts '', '-- select --'
  pp users = prepare(User, 'select * from users').execute.to_a

  puts '', '-- update --'
  update(User, *users.map!{|user| user.name = 'Fred Nurk'; user})
  pp prepare(User, 'select * from users').execute.to_a

  puts '', '-- get --'
  pp get(User, id: 1)
end

