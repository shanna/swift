#!/usr/bin/ruby

require 'etc'
require 'stringio'
require 'benchmark'
require_relative '../lib/swift'

$driver = ARGV[0] || 'postgresql'

Swift.setup :default, db: 'swift', user: Etc.getlogin, driver: $driver

class SwiftUser < Swift.resource do
    store    :users
    attribute :id,         Integer, serial: true, key: true
    attribute :name,       String
    attribute :email,      String
    attribute :updated_at, Time
  end
end # SwiftUser

rows = (ARGV[1] || 500).to_i
iter = (ARGV[2] ||   5).to_i

SwiftUser.migrate!
Benchmark.bm(16) do |bm|
  bm.report("swift #create") do
    rows.times {|n| SwiftUser.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
  end
  bm.report("swift #select") do
    iter.times {|n| SwiftUser.all.each{|m| [ m.id, m.name, m.email, m.updated_at ] } }
  end
  bm.report("swift #update") do
    iter.times {|n| SwiftUser.all.each{|m| m.update(name: "foo", email: "foo@example.com", updated_at: Time.now) } }
  end
end

SwiftUser.migrate!
Benchmark.bm(16) do |bm|
  bm.report("swift #write") do
    n = 0
    Swift.db.write("users", *%w{name email updated_at}) do
      data = n < rows ? "test #{n}\ttest@example.com\t#{Time.now}\n" : nil
      n += 1
      data
    end
  end
end
