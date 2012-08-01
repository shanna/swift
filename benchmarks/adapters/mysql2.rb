require 'bundler/setup'

require 'mysql2'

class Runner
  attr_reader :tests, :driver, :runs, :rows, :adapter
  def initialize opts={}
    %w(driver tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end
    @adapter = Mysql2::Client.new
    @adapter.query('use swift')
  end

  def run
    return unless driver =~ /mysql/i;
    migrate! if tests.include?(:create)
    yield run_creates if tests.include?(:create)
    yield run_selects if tests.include?(:select)
  end

  def migrate!
    adapter.query('drop table if exists users')
    adapter.query('create table users(id serial, name text, email text, updated_at timestamp, primary key(id))')
  end

  def run_creates
    Benchmark.run("mysql2 #create") do
      rows.times do |n|
        values = [ "test #{n}", 'test@example.com', Time.now.to_s ]
        adapter.query("insert into users(name, email, updated_at) values('%s', '%s', '%s')" % values)
      end
    end
  end

  def run_selects
    Benchmark.run("mysql2 #select") do
      sql = 'select * from users'
      runs.times { adapter.query(sql).each {|r| r.values_at(*%w(id name email updated_at)) } }
    end
  end
end
