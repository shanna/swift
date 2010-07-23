#!/usr/bin/env ruby
require_relative '../lib/swift'
require 'etc'

Swift.setup user: Etc.getlogin, db: 'swift', driver: ARGV[0] || 'postgresql'
Swift.trace true

# create table.
puts ''
puts '-- creating table -- '

# create test table
Swift.db.execute 'drop table if exists users'
Swift.db.execute 'create table users(id serial, name text, email text, balance numeric(6,4), created_at timestamp)'

puts ''
puts '-- inserting test data -- '

Swift.db do
  st = prepare('insert into users(name, email, balance, created_at) values(?, ?, ?, ?)')

  sample = DATA.read.split(/\n/).map {|v| v.split(/\t+/) }
  sample.each {|s| st.execute(*s, 1.725, Time.now) }

  puts ''
  puts '-- select and print results -- '

  st = prepare "SELECT * FROM users WHERE id > ?"
  st.execute(0) {|r| p r }

  puts ''
  puts '-- select and print a row -- '
  p st.execute(2).first

  puts ''
  puts '-- select and fetch the raw data -- '
  p st.execute(2).fetchrow

  puts ''
  puts '-- nested transactions -- '

  transaction do
    puts ''
    puts '-- delete user id = 2 -- '
    execute("delete from users where id = 2");

    begin
      transaction do
        puts ''
        puts '-- delete all users -- '
        execute("delete from users");
        raise "Raise error deleting all users"
      end
    rescue => e
      puts "#{e}"
    end
  end

  puts ''
  puts '-- select and print results one by one -- '
  st.execute(0) {|r| p r }
end

__END__
Apple Arthurton	apple@example.com
Benny Arthurton	benny@example.com
James Arthurton	james@example.com
