#!/usr/bin/ruby
require_relative '../lib/swift'
require_relative 'gems/environment'
require 'dm-core'
require 'dm-migrations'
require 'benchmark'
require 'i18n'
require 'active_support'
require 'active_record'
require 'pg'
require 'etc'

Swift.setup :default, db: 'swift', user: Etc.getlogin, driver: 'postgresql'
DataMapper.setup :default, 'postgres://127.0.0.1/swift'

class DMUser
  include DataMapper::Resource
  storage_names[:default] = 'users'
  property :id,         Serial
  property :name,       String
  property :email,      String
  property :updated_at, Time
end # DMUser

class SwiftUser < Swift.resource do
    store    :users
    property :id,         Integer, serial: true, key: true
    property :name,       String
    property :email,      String
    property :updated_at, Time
  end
end # SwiftUser

class ARUser < ActiveRecord::Base
  set_table_name 'users'
  establish_connection adapter: 'postgresql', host: '127.0.0.1', user: Etc.getlogin, database: 'swift'
end # ARUser

rows = 500
iter = 10

DMUser.auto_migrate!
Benchmark.bm(12) do |bm|
  bm.report("dm create") do
    rows.times {|n| DMUser.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
  end
  bm.report("dm select") do
    iter.times { DMUser.all.each {|m| [ m.id, m.name, m.email, m.updated_at ] } }
  end
  bm.report("dm update") do
    iter.times { DMUser.all.each {|m| m.update(name: "foo", email: "foo@example.com", updated_at: Time.now) } }
  end
end

DMUser.auto_migrate!
Benchmark.bm(12) do |bm|
  bm.report("ar create") do
    rows.times {|n| ARUser.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
  end
  bm.report("ar select") do
    iter.times {|n| ARUser.find(:all).each {|m| [ m.id, m.name, m.email, m.updated_at ] } }
  end
  bm.report("ar update") do
    iter.times do |n|
      ARUser.find(:all).each do |m|
        m.update_attributes(name: "foo", email: "foo@example.com", updated_at: Time.now)
      end
    end
  end
end

DMUser.auto_migrate!
Benchmark.bm(12) do |bm|
  bm.report("swift create") do
    rows.times {|n| SwiftUser.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
  end
  bm.report("swift select") do
    iter.times {|n| SwiftUser.all.each{|m| [ m.id, m.name, m.email, m.updated_at ] } }
  end
  bm.report("swift update") do
    iter.times {|n| SwiftUser.all.each{|m| m.update(name: "foo", email: "foo@example.com", updated_at: Time.now) } }
  end
end
