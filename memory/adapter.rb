#!/usr/bin/ruby

require 'etc'
require_relative '../lib/swift'

adapter = ARGV.first =~ /mysql/i ? Swift::DB::Mysql : Swift::DB::Postgres
h = Swift.setup :default, adapter, user: Etc.getlogin, db: 'swift'

rows = (ARGV[1] || 500).to_i
iter = (ARGV[2] ||   5).to_i

50.times do |r|
  puts ""
  puts "-- run #{r} --"
  puts ""

  puts `top -n1 -bp #{$$} | grep #{Etc.getlogin}`

  h.execute 'drop table if exists users'
  h.execute 'create table users(id serial, name text, email text, updated_at timestamp)'

  ins = h.prepare 'insert into users(name, email, updated_at) values (?, ?, ?)'
  rows.times {|n| ins.execute("test #{n}", "test@example.com", Time.now) }
  ins.finish

  sel = h.prepare 'select * from users'
  iter.times {|n| sel.execute {|m| [ m[:id], m[:name], m[:email], m[:updated_at ] ] } }

  upd = h.prepare 'update users set name = ?, email = ?, updated_at = ? where id = ?'
  iter.times {|n| sel.execute {|m| upd.execute("foo", "foo@example.com", Time.now, m[:id]) } }

  puts `top -n1 -bp #{$$} | grep #{Etc.getlogin}`

  ins.finish
  sel.finish
  upd.finish

  GC.start

  puts `top -n1 -bp #{$$} | grep #{Etc.getlogin}`
end
