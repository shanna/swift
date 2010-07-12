#!/usr/bin/ruby

require 'etc'
require 'pp'
require_relative '../lib/swift'
require_relative '../lib/swift/pool'

Swift.setup :pg, db: "dbicpp", user: Etc.getlogin, driver: "postgresql"

Swift.pool(5, :pg) do
  (1..10).each do |n|
    pause = (10-n)/20.0
    execute("select pg_sleep(#{pause}), * from users where id = ?", n) {|r| pp r.fetchrow }
  end
end

EM.run {
  pool1 = Swift.pool(1, :pg)
  pool2 = Swift.pool(1, :pg)

  pool1.execute("select * from users limit 5 offset 0") do |rs|
    puts "Inside pool1 #callback"
    rs.each {|r| pp r }
    pool1.execute("select * from users limit 5 offset 5") do |rs|
      puts "Inside pool1 second #callback"
      rs.each {|r| pp r }
      EM.stop
    end
  end

  pool2.execute("select * from users limit 5 offset 10") do |rs|
    puts "Inside pool2 #callback"
    rs.each {|r| pp r }
  end
}
