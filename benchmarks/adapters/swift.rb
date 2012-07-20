$:.unshift(File.join(File.dirname(__FILE__), '..', '..', 'lib'))

require 'benchmark'
require 'bundler/setup'

require 'swift'
require 'swift/adapter/mysql'
require 'swift/adapter/postgres'
require 'swift/adapter/sqlite3'

class Runner
  attr_reader :tests, :driver, :runs, :rows
  def initialize options = {}
    klass = case @driver = options[:driver]
      when /postgresql/ then Swift::Adapter::Postgres
      when /mysql/      then Swift::Adapter::Mysql
      when /sqlite3/    then Swift::Adapter::Sqlite3
    end

    %w(tests runs rows).each do |name|
      instance_variable_set("@#{name}", options[name.to_sym])
    end
    Swift.setup :default, klass, db: 'swift', ssl: {sslmode: 'disable'}
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
      db = Swift.db
      rows.times do |n|
        values = [ "test #{n}", 'test@example.com', Time.now.to_s ]
        db.execute("insert into users(name, email, updated_at) values('%s', '%s', '%s')" % values)
      end
    end
  end

  def run_selects
    Benchmark.run("swift #select") do
      db = Swift.db
      fields = %w(id name email updated_at).map(&:to_sym)
      runs.times { db.execute('select * from users').each {|m| m.values_at(*fields) } }
    end
  end
end
