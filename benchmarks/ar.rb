#!/usr/bin/ruby
require_relative 'gems/environment'

require 'etc'
require 'benchmark'

require 'pg'
require 'mysql2'
require 'i18n'
require 'active_support'
require 'active_record'

$driver = ARGV[0] || 'postgresql'
$driver = $driver =~ /mysql/ ? 'mysql2' : $driver

class ARUser < ActiveRecord::Base
  set_table_name 'users'
  establish_connection adapter: $driver, host: '127.0.0.1', user: Etc.getlogin, database: 'swift'
end # ARUser

rows = (ARGV[1] || 500).to_i
iter = (ARGV[2] ||   5).to_i

ARUser.connection.execute 'truncate users'

Benchmark.bm(16) do |bm|
  bm.report("ar #create") do
    rows.times {|n| ARUser.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
  end
  bm.report("ar #select") do
    iter.times {|n| ARUser.find(:all).each {|m| [ m.id, m.name, m.email, m.updated_at ] } }
  end
  bm.report("ar #update") do
    iter.times do |n|
      ARUser.find(:all).each do |m|
        m.update_attributes(name: "foo", email: "foo@example.com", updated_at: Time.now)
      end
    end
  end
end

puts 'virt: %skB res: %skB' % `ps -o "vsize= rss=" -p #{$$}`.strip.split(/\s+/)
