#!/usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'pp'
require 'swift'
require 'swift/migrations'

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

Swift.setup :default, adapter, db: 'swift'
Swift.trace true

puts '-- migrate! --'
User.migrate!

puts '', '-- create --'
User.create name: 'Apple Arthurton', email: 'apple@arthurton.local'
User.create name: 'Benny Arthurton', email: 'benny@arthurton.local'

puts '', '-- all --'
pp User.all.to_a

puts '', '-- first --'
pp User.first(':name like ?', '%Arthurton')

puts '', '-- get --'
pp user = User.get(id: 2)
pp user = User.get(id: 2)

puts '', '-- update --'
user.update(name: 'Jimmy Arthurton')

puts '', '-- destroy --'
user.destroy

puts '', '-- all --'
pp User.all.to_a
