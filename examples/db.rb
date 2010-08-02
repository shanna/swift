#!/usr/bin/env ruby
require_relative '../lib/swift'
require 'pp'

class User < Swift::Scheme
  store     :users
  attribute :id,    Swift::Type::Integer, serial: true, key: true
  attribute :name,  Swift::Type::String
  attribute :email, Swift::Type::String
end # User

adapter = ARGV.first =~ /mysql/i ? Swift::DB::Mysql : Swift::DB::Postgres
puts "Using DB: #{adapter}"

Swift.setup :default, adapter, db: 'swift'
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

  puts '', '-- destroy --'
  pp destroy(User, id: 1)
end

