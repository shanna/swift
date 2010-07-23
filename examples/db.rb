#!/usr/bin/env ruby
require_relative '../lib/swift'
require 'etc'
require 'pp'

class User < Swift.resource do
    store    :users
    property :id,    Integer, serial: true, key: true
    property :name,  String
    property :email, String
  end
end # User

Swift.setup user: Etc.getlogin, db: 'swift', driver: ARGV[0] || 'postgresql'
Swift.trace true

Swift.db do
  migrate! User

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

