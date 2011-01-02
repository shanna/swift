#!/usr/bin/ruby

require_relative 'gems/environment'
require 'etc'
require 'sequel'

class Runner
  attr_reader :tests, :driver, :runs, :rows
  def initialize opts={}
    @driver = (opts[:driver] || 'postgres').sub(/postgresql/, 'postgres')
    %w(tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end
    uri = 'swift://127.0.0.1/swift?db_type=' + @driver
    Object.const_set :DB, Sequel.connect(uri)
    Object.const_set :User, Sequel::Model(:users)
  end

  def run
    User.truncate if tests.include?(:create)
    yield run_creates if tests.include?(:create)
    yield run_selects if tests.include?(:select)
    yield run_updates if tests.include?(:update)
  end

  def run_creates
    Benchmark.run("sequel(swift) #create") do
      rows.times {|n| User.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
    end
  end

  def run_selects
    Benchmark.run("sequel(swift) #select") do
      runs.times { User.each {|m| [ m.id, m.name, m.email, m.updated_at ] } }
    end
  end

  def run_updates
    Benchmark.run("sequel(swift) #update") do
      runs.times do |n|
        User.all do |m|
          m.update(name: "foo", email: "foo@example.com", updated_at: Time.now)
        end
      end
    end
  end
end
