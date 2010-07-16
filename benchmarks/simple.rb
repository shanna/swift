#!/usr/bin/ruby

require_relative '../lib/swift'
require_relative '../lib/swift/sugar'
require_relative 'gems/environment'
require 'dm-core'
require 'benchmark'
require 'i18n'
require 'active_support'
require 'active_record'
require 'pg'
require 'etc'

Swift.setup :default, db: 'swift', user: Etc.getlogin, driver: 'postgresql'
DataMapper.setup :default, 'postgres://127.0.0.1/swift'

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

class ARUser < ActiveRecord::Base
  set_table_name 'users'
  establish_connection adapter: 'postgresql', host: '127.0.0.1', user: Etc.getlogin, database: 'swift'
end


rows = 2000
iter = 10
User.auto_migrate!

Benchmark.bm(12) do |bm|
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

Benchmark.bm(12) do |bm|
  bm.report("ar create") do
    rows.times {|n| ARUser.create(name: "test #{n}", email: "test@example.com") }
  end
  bm.report("ar select") do
    iter.times {|n| ARUser.find(:all).each {|m| m } }
  end
  bm.report("ar update") do
    iter.times {|n| ARUser.find(:all).each {|m| m.update_attributes(name: "foo", email: "foo@example.com") } }
  end
end

User.auto_migrate!

Benchmark.bm(12) do |bm|
  bm.report("swift create") do
    rows.times {|n| SwiftUser.create(name: "test #{n}", email: "test@example.com") }
  end
  bm.report("swift select") do
    iter.times {|n| SwiftUser.all.each {|m| m } }
  end
  bm.report("swift update") do
    iter.times {|n| SwiftUser.all.each {|m| m.update(name: "foo", email: "foo@example.com") } }
  end
end
