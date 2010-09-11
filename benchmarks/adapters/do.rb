require_relative '../gems/environment'
require 'data_objects'
require 'do_mysql'
require 'do_postgres'

module DataObjects
  class Connection
    def query sql, *args
      create_command(sql).execute_reader(*args)
    end
    def execute sql, *args
      create_command(sql).execute_non_query(*args)
    end
  end
end

class Runner
  attr_reader :tests, :driver, :runs, :rows, :adapter
  def initialize opts={}
    %w(driver tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end
    @driver = @driver =~ /postgres/ ? 'postgres' : driver
    @adapter = DataObjects::Connection.new("#{driver}://127.0.0.1/swift")
  end

  def run
    migrate! if tests.include?(:create)
    yield run_creates if tests.include?(:create)
    yield run_selects if tests.include?(:select)
  end

  def migrate!
    adapter.execute('drop table if exists users')
    adapter.execute('create table users(id serial, name text, email text, updated_at timestamp, primary key(id))')
  end

  def run_creates
    Benchmark.run("do #create") do
      rows.times do |n|
        values = [ "test #{n}", 'test@example.com', Time.now ]
        adapter.execute("insert into users(name, email, updated_at) values(?, ?, ?)", *values)
      end
    end
  end

  def run_selects
    Benchmark.run("do #select") do
      sql = 'select * from users'
      runs.times {|n| adapter.query(sql).each {|r| r.values_at(*%w(id name email updated_at)) } }
    end
  end
end
