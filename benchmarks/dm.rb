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
  attr_reader :tests, :driver, :runs, :rows, :results
  def initialize opts={}
    @results = []
    @driver  = opts[:driver] =~ /postgresql/ ? 'postgres' : opts[:driver]
    %w(tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end
    DataMapper.setup :default, "#{@driver}://127.0.0.1/swift"
  end

  def run
    GC.disable
    User.auto_migrate! if tests.include?(:create) or tests.include?(:update)
    run_creates if tests.include?(:create)
    run_selects if tests.include?(:select)
    run_updates if tests.include?(:update)
    results
  end

  def run_creates
    results << Benchmark.run("dm #create") do
      rows.times {|n| User.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
    end
  end

  def run_selects
    results << Benchmark.run("dm #select") do
      runs.times { User.all.each {|m| [ m.id, m.name, m.email, m.updated_at ] } }
    end
  end

  def run_updates
    results << Benchmark.run("dm #update") do
      runs.times { User.all.each {|m| m.update(name: "foo", email: "foo@example.com", updated_at: Time.now) } }
    end
  end
end
