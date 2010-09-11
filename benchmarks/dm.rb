require_relative 'gems/environment'
require 'etc'
require 'benchmark'
require 'dm-core'
require 'dm-migrations'

class User
  include DataMapper::Resource
  storage_names[:default] = 'users'
  property :id,         Serial
  property :name,       String
  property :email,      String
  property :updated_at, Time
end # User

class Runner
  attr_reader :tests, :driver, :runs, :rows
  def initialize opts={}
    @driver  = opts[:driver] =~ /postgresql/ ? 'postgres' : opts[:driver]
    %w(tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end
    DataMapper.setup :default, {adapter: @driver, database: 'swift', username: Etc.getlogin}
  end

  def run
    User.auto_migrate! if tests.include?(:create)
    yield run_creates if tests.include?(:create)
    yield run_selects if tests.include?(:select)
    yield run_updates if tests.include?(:update)
  end

  def run_creates
    Benchmark.run("dm #create") do
      rows.times {|n| User.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
    end
  end

  def run_selects
    Benchmark.run("dm #select") do
      runs.times { User.all.each {|m| [ m.id, m.name, m.email, m.updated_at ] } }
    end
  end

  def run_updates
    Benchmark.run("dm #update") do
      runs.times { User.all.each {|m| m.update(name: "foo", email: "foo@example.com", updated_at: Time.now) } }
    end
  end
end
