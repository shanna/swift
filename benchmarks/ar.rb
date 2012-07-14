require 'bundler'
Bundler.setup(:default)

require 'etc'
require 'pg'
require 'mysql2'
require 'i18n'
require 'stringio'
require 'active_support'
require 'active_record'

class User < ActiveRecord::Base
  set_table_name 'users'
end # User

class Runner
  attr_reader :tests, :driver, :runs, :rows
  def initialize opts={}
    @driver  = opts[:driver] =~ /mysql/ ? 'mysql2' : opts[:driver]

    %w(tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end

    db = @driver == 'sqlite3' ? ':memory:' : 'swift'
    ActiveRecord::Base.establish_connection adapter: @driver, host: '127.0.0.1', username: Etc.getlogin, database: db
  end

  def run
    migrate!          if tests.include?(:create)
    yield run_creates if tests.include?(:create)
    yield run_selects if tests.include?(:select)
    yield run_updates if tests.include?(:update)
  end

  def migrate!
    ActiveRecord::Base.connection.execute("set client_min_messages=WARNING") rescue nil
    ActiveRecord::Schema.define do
      execute 'drop table if exists users'
      create_table :users do |t|
        t.column :name,       :string
        t.column :email,      :string
        t.column :updated_at, :timestamp
      end
    end
  end

  def run_creates
    Benchmark.run("ar #create") do
      rows.times {|n| User.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
    end
  end

  def run_selects
    Benchmark.run("ar #select") do
      runs.times { User.find(:all).each {|m| [ m.id, m.name, m.email, m.updated_at ] } }
    end
  end

  def run_updates
    Benchmark.run("ar #update") do
      runs.times do |n|
        User.find(:all).each do |m|
          m.update_attributes(name: "foo", email: "foo@example.com", updated_at: Time.now)
        end
      end
    end
  end
end
