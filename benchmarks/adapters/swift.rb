require 'benchmark'
require_relative '../../lib/swift'

class Runner
  attr_reader :tests, :driver, :runs, :rows
  def initialize opts={}
    @driver  = opts[:driver] =~ /postgresql/ ? Swift::DB::Postgres : Swift::DB::Mysql
    %w(tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end
    Swift.setup :default, @driver, db: 'swift'
  end

  def run
    migrate! if tests.include?(:create)
    yield run_creates if tests.include?(:create)
    yield run_selects if tests.include?(:select)
  end

  def migrate!
    Swift.db.execute('drop table if exists users')
    Swift.db.execute('create table users(id serial, name text, email text, updated_at timestamp, primary key(id))')
  end

  def run_creates
    Benchmark.run("swift #create") do
      st = Swift.db.prepare('insert into users(name, email, updated_at) values(?, ?, ?)')
      rows.times {|n| st.execute("test #{n}", "test@example.com", Time.now) }
    end
  end

  def run_selects
    Benchmark.run("swift #select") do
      st = Swift.db.prepare('select * from users')
      runs.times {|n| st.execute {|m| m.values_at(:id, :name, :email, :updated_at) } }
    end
  end
end
