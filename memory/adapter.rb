#!/usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'etc'
require 'swift'

adapter = ARGV.first =~ /mysql/i ? Swift::DB::Mysql : Swift::DB::Postgres
db = Swift.setup :default, adapter, user: Etc.getlogin, db: 'swift'

rows = (ARGV[1] || 500).to_i
iter = (ARGV[2] ||   5).to_i

db.execute 'drop table if exists users'
db.execute 'create table users(id serial, name text, email text, updated_at timestamp)'

50.times do |r|
  db.execute 'truncate users'

  puts '', "-- run #{r} --", ''
  puts 'virt: %skB res: %skB' % `ps -o "vsize= rss=" -p #{$$}`.strip.split(/\s+/)

  insert = db.prepare 'insert into users(name, email, updated_at) values (?, ?, ?)'
  rows.times{|n| insert.execute("test #{n}", "test@example.com", Time.now) }
  insert.finish

  select = db.prepare 'select * from users'
  iter.times{|n| select.execute{|m| [ m[:id], m[:name], m[:email], m[:updated_at ] ] } }

  update = db.prepare 'update users set name = ?, email = ?, updated_at = ? where id = ?'
  iter.times{|n| select.execute{|m| update.execute("foo", "foo@example.com", Time.now, m[:id]) } }

  puts 'virt: %skB res: %skB' % `ps -o "vsize= rss=" -p #{$$}`.strip.split(/\s+/)

  insert.finish
  select.finish
  update.finish

  GC.start
  puts 'virt: %skB res: %skB' % `ps -o "vsize= rss=" -p #{$$}`.strip.split(/\s+/)
end
