#!/usr/bin/ruby

require_relative '../lib/swift'
require_relative '../lib/swift/pool'
require 'gems/environment'
require 'dm-core'
require 'benchmark'
require 'etc'

Swift.setup :default, db: 'dbicpp', user: Etc.getlogin, driver: 'postgresql'
DataMapper.setup :default, 'postgres://127.0.0.1/dbicpp'

class User
  include DataMapper::Resource
  property :id,    Serial
  property :name,  String
  property :email, String
end # User

class SwiftUser < Swift.model do
    resource :users
    property :id,       Integer, key: true, serial: true
    property :name,     String
    property :email,    String
  end
end # SwiftUser

rows = 2000
iter = 10
User.auto_migrate!

Benchmark.bm(10) do |bm|
  bm.report("dm create") do
    rows.times {|n| User.create(name: "test #{n}", email: "test@example.com") }
  end
  bm.report("dm select") do
    iter.times { User.all.each {|m| m } }
  end
  bm.report("dm update") do
    iter.times { User.all.each {|m| m.update(name: "foo", email: "foo@example.com") } }
  end
end

User.auto_migrate!

Benchmark.bm(10) do |bm|
  bm.report("swift create") do
    Swift.db do
      rows.times {|n| create(SwiftUser, { name: "test #{n}", email: "test@example.com" }) }
    end
  end
  bm.report("swift select") do
    Swift.db do
      iter.times {|n| prepare(SwiftUser, "select * from users").execute.map {|m| m } }
    end
  end
  bm.report("swift update") do
    Swift.db do
      iter.times do |n|
        update SwiftUser, *prepare(SwiftUser, "select * from users").execute.map {|m| m.name = "foo"; m }
      end
    end
  end
end
