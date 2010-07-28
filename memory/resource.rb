#!/usr/bin/ruby

require 'etc'
require_relative '../lib/swift'

$driver = ARGV[0] || 'postgresql'

Swift.setup db: 'swift', user: Etc.getlogin, driver: $driver

class User < Swift::Scheme
  store     :users
  attribute :id,         Swift::Type::Integer, serial: true, key: true
  attribute :name,       Swift::Type::String
  attribute :email,      Swift::Type::String
  attribute :updated_at, Swift::Type::Time
end # User

rows = (ARGV[1] || 500).to_i
iter = (ARGV[2] ||   5).to_i

50.times do |r|
  puts ""
  puts "-- run #{r} --"
  puts ""

  puts `top -n1 -bp #{$$} | grep #{Etc.getlogin}`

  User.migrate!
  rows.times {|n| User.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
  iter.times {|n| User.all.each{|m| [ m.id, m.name, m.email, m.updated_at ] } }
  iter.times {|n| User.all.each{|m| m.update(name: "foo", email: "foo@example.com", updated_at: Time.now) } }

  User.migrate!
  n = 0
  Swift.db.write("users", *%w{name email updated_at}) do
    data = n < rows ? "test #{n}\ttest@example.com\t#{Time.now}\n" : nil
    n += 1
    data
  end

  puts `top -n1 -bp #{$$} | grep #{Etc.getlogin}`

  GC.start

  puts `top -n1 -bp #{$$} | grep #{Etc.getlogin}`
end
