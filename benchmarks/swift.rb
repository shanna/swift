#!/usr/bin/ruby

require 'etc'
require 'stringio'
require 'benchmark'
require_relative '../lib/swift'

adapter = ARGV.shift =~ /mysql/i ? Swift::DB::Mysql : Swift::DB::Postgres
Swift.setup :default, adapter, user: Etc.getlogin, db: 'swift'

class User < Swift::Scheme
  store     :users
  attribute :id,         Swift::Type::Integer, serial: true, key: true
  attribute :name,       Swift::Type::String
  attribute :email,      Swift::Type::String
  attribute :updated_at, Swift::Type::Time
end # User

rows = (ARGV.shift || 500).to_i
iter = (ARGV.shift ||   5).to_i

Benchmark.bm(16) do |bm|
  Swift.db do
    User.migrate!
    bm.report("swift #create") do
      rows.times {|n| User.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
    end
    bm.report("swift #select") do
      iter.times {|n| User.all.each{|m| [ m.id, m.name, m.email, m.updated_at ] } }
    end
    bm.report("swift #update") do
      iter.times {|n| User.all.each{|m| m.update(name: "foo", email: "foo@example.com", updated_at: Time.now) } }
    end
    execute('truncate users')
    bm.report("swift #write") do
      n = 0
      write("users", *%w{name email updated_at}) do
        data = n < rows ? "test #{n}\ttest@example.com\t#{Time.now}\n" : nil
        n += 1
        data
      end
    end
  end
end

puts 'virt: %skB res: %skB' % `ps -o "vsize= rss=" -p #{$$}`.strip.split(/\s+/)
