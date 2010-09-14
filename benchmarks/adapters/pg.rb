require_relative '../gems/environment'
require 'pg'
require 'date'
require_relative 'pg_ext/pg_ext'

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

  def typecast type, value
    return value if value.nil?
    case type
      when 16
        value == 't'
      when 20,21,22,23,26
        value.to_i
      when 700,701,790,1700
        value.to_f
      when 1082
        PGconn.typecast_date(value)
      when 1114, 1184
        PGconn.typecast_timestamp(value)
      else
        value
    end
  end

  def run_selects
    Benchmark.run("pg #select") do
      sql = 'select * from users'
      runs.times do |n|
        r = adapter.exec(sql)
        ftypes = r.nfields.times.map {|col| r.ftype(col) }
        fnames = r.nfields.times.map {|col| r.fname(col).to_sym }
        r.ntuples.times do |row|
          Hash[*fnames.zip(r.nfields.times.map {|col| typecast(ftypes[col], r.getvalue(row, col)) }).flatten]
        end
      end
    end
  end
end
