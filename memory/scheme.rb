#!/usr/bin/env ruby

# TODO: make this a test.

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
db   = Swift.db

User.migrate!

50.times do |r|
  db.execute 'truncate users'

  puts '', "-- run #{r} --", ''
  puts 'virt: %skB res: %skB' % `ps -o "vsize= rss=" -p #{$$}`.strip.split(/\s+/)

  select = db.prepare(User, %Q{select * from #{User}})
  rows.times{|n| User.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now)}
  iter.times{|n| select.execute{|m| [m.id, m.name, m.email, m.updated_at]}}
  iter.times{|n| select.execute{|m| m.update(name: "foo", email: "foo@example.com", updated_at: Time.now)}}

  db.execute %Q{truncate #{User}}
  rows.times{|n| db.write(User, %w{name email updated_at}, "test #{n}\ttest@example.com\t#{Time.now}\n")}
  puts 'virt: %skB res: %skB' % `ps -o "vsize= rss=" -p #{$$}`.strip.split(/\s+/)

  GC.start
  puts 'virt: %skB res: %skB' % `ps -o "vsize= rss=" -p #{$$}`.strip.split(/\s+/)
end
