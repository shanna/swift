#!/usr/bin/ruby

require_relative 'gems/environment'
require 'etc'
require 'sequel'

class Runner
  attr_reader :tests, :driver, :runs, :rows
  def initialize opts={}
    @driver  = case opts[:driver]
    when /mysql/
      'mysql2'
    when /postgres/
      'postgres'
    else
      opts[:driver]
    end
    %w(tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end
    Object.const_set :DB, Sequel.connect(adapter: @driver, host: '127.0.0.1', user: Etc.getlogin, database: 'swift')
    Object.const_set :User, Sequel::Model(:users)
  end

  def run
    GC.disable
    User.truncate if tests.include?(:create) or tests.include?(:update)
    yield run_creates if tests.include?(:create)
    yield run_selects if tests.include?(:select)
    yield run_updates if tests.include?(:update)
  end

  def run_creates
    Benchmark.run("sequel #create") do
      rows.times {|n| User.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
    end
  end

  def run_selects
    Benchmark.run("sequel #select") do
      runs.times {|n| User.each {|m| [ m.id, m.name, m.email, m.updated_at ] } }
    end
  end

  def run_updates
    Benchmark.run("sequel #update") do
      runs.times do |n|
        User.all do |m|
          m.update(name: "foo", email: "foo@example.com", updated_at: Time.now)
        end
      end
    end
  end
end
