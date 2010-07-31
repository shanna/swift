#!/usr/bin/ruby
require_relative 'gems/environment'

require 'etc'
require 'benchmark'

require 'dm-core'
require 'dm-migrations'

$driver = ARGV[0] || 'postgres'
$driver = $driver =~ /postgres/ ? 'postgres' : $driver

DataMapper.setup :default, "#{$driver}://127.0.0.1/swift"

class DMUser
  include DataMapper::Resource
  storage_names[:default] = 'users'
  property :id,         Serial
  property :name,       String
  property :email,      String
  property :updated_at, Time
end # DMUser

rows = (ARGV[1] || 500).to_i
iter = (ARGV[2] ||   5).to_i

GC.disable
DMUser.auto_migrate!
Benchmark.bm(16) do |bm|
  bm.report("dm #create") do
    rows.times {|n| DMUser.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
  end
  bm.report("dm #select") do
    iter.times { DMUser.all.each {|m| [ m.id, m.name, m.email, m.updated_at ] } }
  end
  bm.report("dm #update") do
    iter.times { DMUser.all.each {|m| m.update(name: "foo", email: "foo@example.com", updated_at: Time.now) } }
  end
end

puts 'virt: %skB res: %skB' % `ps -o "vsize= rss=" -p #{$$}`.strip.split(/\s+/)
