#!/usr/bin/ruby

require_relative '../lib/swift'
require_relative '../lib/swift/pool'

adapter = ARGV.first =~ /mysql/i ? Swift::DB::Mysql : Swift::DB::Postgres
puts "Using DB: #{adapter}"

Swift.setup :default, adapter, db: 'swift'
Swift.trace true

# create test table
Swift.db do |db|
  puts '-- create --'
  db.execute('DROP TABLE IF EXISTS users')
  db.execute('CREATE TABLE users(id serial, name text, email text)')

  sample = DATA.read.split(/\n/).map {|v| v.split(/\t+/) }

  puts '-- insert --'
  ins = db.prepare('insert into users(name, email) values(?, ?)')
  9.times {|n| ins.execute(*sample[n%3]) }
end

sleep_clause = {
  Swift::DB::Postgres => "case length(pg_sleep(%s)::text) when 0 then '%s' else '%s' end as sleep",
  Swift::DB::Mysql    => "if (sleep(%s), '%s', '%s') as sleep"
}

puts '-- select 9 times with a pool of size 5 --'
Swift.trace false
Swift.pool(5) do |db|
  (1..9).each do |n|
    pause = '%0.3f' % ((20-n)/20.0)
    pause = sleep_clause[adapter] % 3.times.map { pause }
    db.execute("select *, #{pause} from users where id = ?", n) {|r| p r.first }
  end
end
Swift.trace true

puts '-- multiple pools: size 2, size 1 --'
EM.run {
  pool1 = Swift.pool(2)
  pool2 = Swift.pool(1)

  pool1.execute("select * from users limit 3 offset 0") do |rs|
    puts '-- Inside pool1 #callback --'
    rs.each {|r| p r }
    pool1.execute("select * from users limit 3 offset 3") do |rs|
      puts '-- Inside pool1 #callback again --'
      rs.each {|r| p r }
      EM.stop
    end
  end

  pool2.execute("select * from users limit 3 offset 6") do |rs|
    puts '-- Inside pool2 #callback --'
    rs.each {|r| p r }
  end
}

__END__
Apple Arthurton	apple@example.com
Benny Arthurton	benny@example.com
James Arthurton	james@example.com
