#!/usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'swift'
require 'swift/migrations'

adapter = ARGV.first =~ /mysql/i ? Swift::DB::Mysql : Swift::DB::Postgres
Swift.setup :default, adapter, db: 'swift'

class User < Swift::Scheme
  store     :users
  attribute :id,         Swift::Type::Integer, serial: true, key: true
  attribute :name,       Swift::Type::String
  attribute :email,      Swift::Type::String
  attribute :updated_at, Swift::Type::Time
end # User

rows = (ARGV[1] || 500).to_i
iter = (ARGV[2] ||   5).to_i

User.migrate!

50.times do |r|
  Swift.db.execute 'truncate users'

  puts '', "-- run #{r} --", ''
  puts 'virt: %skB res: %skB' % `ps -o "vsize= rss=" -p #{$$}`.strip.split(/\s+/)

  users = User.prepare("select * from #{User.store}")
  rows.times{|n| User.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
  iter.times{|n| users.execute.each{|m| [ m.id, m.name, m.email, m.updated_at ] } }
  iter.times{|n| users.execute.each{|m| m.update(name: "foo", email: "foo@example.com", updated_at: Time.now) } }

  Swift.db.execute 'truncate users'
  rows.times{|n| Swift.db.write('users', %w{name email updated_at}, "test #{n}\ttest@example.com\t#{Time.now}\n") }
  puts 'virt: %skB res: %skB' % `ps -o "vsize= rss=" -p #{$$}`.strip.split(/\s+/)

  GC.start
  puts 'virt: %skB res: %skB' % `ps -o "vsize= rss=" -p #{$$}`.strip.split(/\s+/)
end
