#!/usr/bin/ruby

require_relative '../lib/swift'
require_relative '../lib/swift/pool'

adapter = ARGV.first =~ /mysql/i ? Swift::DB::Mysql : Swift::DB::Postgres
puts "Using DB: #{adapter}"

Swift.setup :default, adapter, db: 'swift'
Swift.trace true

# create test table
Swift.db do
  puts '-- create --'
  execute('DROP TABLE IF EXISTS users')
  execute('CREATE TABLE users(id serial, name text, email text)')

  sample = DATA.read.split(/\n/).map {|v| v.split(/\t+/) }

  puts '-- insert --'
  ins = prepare('insert into users(name, email) values(?, ?)')
  10.times {|n| ins.execute(*sample[n%3]) }
end

puts '-- select 9 times with a pool of size 5 --'
Swift.trace false
Swift.pool(5) do
  (1..9).each do |n|
    pause = '%0.3f' % ((20-n)/20.0)
    pause = "case length(pg_sleep(#{pause})::text) when 0 then '#{pause}' else '' end as sleep"
    execute("select #{pause}, * from users where id = ?", n) {|r| p r.first }
  end
end
Swift.trace true

puts '-- multiple pools: size 2, size 1 --'
EM.run {
  pool1 = Swift.pool(2)
  pool2 = Swift.pool(1)

  pool1.execute("select * from users limit 5 offset 0") do |rs|
    puts '-- Inside pool1 #callback --'
    rs.each {|r| p r }
    pool1.execute("select * from users limit 5 offset 5") do |rs|
      puts '-- Inside pool1 #callback again --'
      rs.each {|r| p r }
      EM.stop
    end
  end

  pool2.execute("select * from users limit 5 offset 10") do |rs|
    puts '-- Inside pool2 #callback --'
    rs.each {|r| p r }
  end
}

__END__
Apple Arthurton	apple@example.com
Benny Arthurton	benny@example.com
James Arthurton	james@example.com
