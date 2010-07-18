#!/usr/bin/env ruby
require_relative '../ext/swift/dbi'
require 'etc'
require 'pp'

Swift::DBI.trace true
h = Swift::DBI::Handle.new user: Etc.getlogin, db: 'swift', driver: ARGV[0] || 'postgresql'

# create table.
puts 'Creating table'
puts "--------------\n"

# create test table
h.execute('DROP TABLE IF EXISTS users');
h.execute('CREATE TABLE users(id serial, name text, email text, balance numeric, created_at timestamp)');

puts ''
puts 'Inserting test data'
puts "-------------------\n"

st = h.prepare('insert into users(name, email, balance, created_at) values(?, ?, ?, ?)')

sample = DATA.read.split(/\n/).map {|v| v.split(/\t+/) }
sample.each {|s| st.execute(*s, 1.725, Time.now) }

puts "\nSELECT and print results"
puts "------------------------\n"

st = h.prepare "SELECT * FROM users WHERE id > ?"
st.execute(0) {|r| p r }

puts "\nSELECT and print first row"
puts "--------------------------\n"
p st.execute(2).first

puts "\nSELECT and print first row as array"
puts "-----------------------------------\n"
p st.execute(2).fetchrow

puts "\nNested transactions"
puts "===================\n"

h.transaction {

  puts "\nDelete user id = 2"
  puts "------------------\n"
  h.execute("DELETE FROM users WHERE id = 2");

  begin
    h.transaction {
      puts "\nDelete all users"
      puts "----------------\n"
      h.execute("DELETE FROM users");
      raise "Raise error deleting all users"
    }
  rescue => e
    puts "#{e}"
  end
}

puts "\nSELECT and print results one by one"
puts "-----------------------------------\n"

st.execute(0) {|r| p r }

__END__
Apple Arthurton	apple@example.com
Benny Arthurton	benny@example.com
James Arthurton	james@example.com
