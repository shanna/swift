#!/usr/bin/env ruby
require_relative '../lib/swift'
require 'etc'
require 'pp'

class User < Swift::Scheme
  store     :users
  attribute :id,       Swift::Type::Integer, serial: true, key: true
  attribute :name,     Swift::Type::String
  attribute :email,    Swift::Type::String
  attribute :active,   Swift::Type::Boolean
  attribute :created,  Swift::Type::Time,   default: proc { Time.now }
  attribute :optional, Swift::Type::String, default: 'woot'
end # User

adapter = ARGV.first =~ /mysql/i ? Swift::DB::Mysql : Swift::DB::Postgres
puts "Using DB: #{adapter}"

Swift.setup :default, adapter, user: Etc.getlogin, db: 'swift'
Swift.trace true

Swift.db do
  puts '-- migrate! --'
  User.migrate!

  puts '', '-- create --'
  User.create name: 'Apple Arthurton', email: 'apple@arthurton.local'
  User.create name: 'Benny Arthurton', email: 'benny@arthurton.local'

  puts '', '-- all --'
  pp User.all(':name like ? limit 1 offset 1', '%Arthurton').first

  puts '', '-- get --'
  pp user = User.get(id: 2)
  pp user = User.get(id: 2)

  puts '', '-- update --'
  user.update(name: 'Jimmy Arthurton')

  puts '', '-- destroy --'
  user.destroy
end
