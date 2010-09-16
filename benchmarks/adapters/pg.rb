require_relative '../gems/environment'
require 'pg'
require 'date'
require 'pg_typecast'

class Runner
  attr_reader :tests, :driver, :runs, :rows, :adapter
  def initialize opts={}
    %w(driver tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end
    @adapter = PGconn.connect 'host=127.0.0.1 dbname=swift'
  end

  def run
    return unless driver =~ /postgres/i;
    migrate! if tests.include?(:create)
    yield run_creates if tests.include?(:create)
    yield run_selects if tests.include?(:select)
  end

  def migrate!
    adapter.exec('drop table if exists users')
    adapter.exec('create table users(id serial, name text, email text, updated_at timestamp, primary key(id))')
  end

  def run_creates
    Benchmark.run("pg #create") do
      rows.times do |n|
        values = [ "test #{n}", 'test@example.com', Time.now.to_s ]
        adapter.exec("insert into users(name, email, updated_at) values('%s', '%s', '%s')" % values)
      end
    end
  end

  def run_selects
    Benchmark.run("pg #select") do
      sql    = 'select * from users'
      fields = %w(id name email updated_at).map(&:to_sym)
      runs.times { adapter.exec(sql).each {|r| r.values_at(*fields) } }
    end
  end
end
