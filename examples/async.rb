#!/usr/bin/ruby

require 'etc'
require 'pp'
require_relative '../lib/swift'
require_relative '../lib/swift/pool'

Swift.setup :pg, db: 'swift', user: Etc.getlogin, driver: 'postgresql'

# create test table
Swift.db(:pg).execute('DROP TABLE IF EXISTS users');
Swift.db(:pg).execute('CREATE TABLE users(id serial, name text, email text)');

sample = DATA.read.split(/\n/).map {|v| v.split(/\t+/) }

ins = Swift.db(:pg).prepare('insert into users(name, email) values(?, ?)')
50.times {|n| ins.execute(*sample[n%3]) }

Swift.pool(5, :pg) do
  (1..10).each do |n|
    execute("select pg_sleep(#{rand(50)/200.0}), * from users where id = ?", n) {|r| pp r.fetchrow }
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

__END__
Apple Arthurton	apple@example.com
Benny Arthurton	benny@example.com
James Arthurton	james@example.com
