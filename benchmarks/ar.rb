require_relative 'gems/environment'
require 'etc'
require 'pg'
require 'mysql2'
require 'i18n'
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
    User.establish_connection adapter: @driver, host: '127.0.0.1', username: Etc.getlogin, database: 'swift'
  end

  def run
    User.connection.execute 'truncate users' if tests.include?(:create)
    yield run_creates if tests.include?(:create)
    yield run_selects if tests.include?(:select)
    yield run_updates if tests.include?(:update)
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
