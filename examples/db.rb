#!/usr/bin/env ruby
require_relative '../lib/swift'
require 'etc'
require 'pp'

class User < Swift::Scheme
  store    :users
  attribute :id,    Swift::Attribute::Integer, serial: true, key: true
  attribute :name,  Swift::Attribute::String
  attribute :email, Swift::Attribute::String
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

