#!/usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'pp'
require 'swift'
require 'swift/migrations'

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

Swift.db do |db|
  db.migrate! User

  puts '-- create --'
  db.create(User,
    {name: 'Apple Arthurton', email: 'apple@arthurton.local'},
    {name: 'Benny Arthurton', email: 'benny@arthurton.local'}
  )

  puts '', '-- select --'
  pp users = db.prepare(User, 'select * from users').execute.to_a

  puts '', '-- update --'
  db.update(User, *users.map!{|user| user.name = 'Fred Nurk'; user})
  pp db.prepare(User, 'select * from users').execute.to_a

  puts '', '-- get --'
  pp db.get(User, id: 1)

  puts '', '-- destroy --'
  pp db.destroy(User, id: 1)
end

