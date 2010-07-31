require 'etc'
require 'benchmark'
require_relative '../lib/swift'

ENV['TZ']='AEST-10:00'

class User < Swift::Scheme
  store     :users
  attribute :id,         Swift::Type::Integer, serial: true, key: true
  attribute :name,       Swift::Type::String
  attribute :email,      Swift::Type::String
  attribute :updated_at, Swift::Type::Time
end # User

class Runner
  attr_reader :tests, :driver, :runs, :rows, :results
  def initialize opts={}
    @results = []
    @driver  = opts[:driver] =~ /postgresql/ ? Swift::DB::Postgres : Swift::DB::Mysql
    %w(tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end
    Swift.setup :default, @driver, user: Etc.getlogin, db: 'swift'
  end

  def run
    GC.disable
    User.migrate! if tests.include?(:create) or tests.include?(:update)
    run_creates if tests.include?(:create)
    run_selects if tests.include?(:select)
    run_updates if tests.include?(:update)
    results
  end

  def run_creates
    results << Benchmark.run("swift #create") do
      rows.times {|n| User.create(name: "test #{n}", email: "test@example.com", updated_at: Time.now) }
    end
  end

  def run_selects
    results << Benchmark.run("swift #select") do
      runs.times {|n| User.all.each{|m| [ m.id, m.name, m.email, m.updated_at ] } }
    end
  end

  def run_updates
    results << Benchmark.run("swift #update") do
      runs.times {|n| User.all.each{|m| m.update(name: "foo", email: "foo@example.com", updated_at: Time.now) } }
    end
    Swift.db.execute('truncate users')
    results << Benchmark.run("swift #write") do
      n = 0
      Swift.db.write("users", *%w{name email updated_at}) do
        data = n < rows ? "test #{n}\ttest@example.com\t#{Time.now}\n" : nil
        n += 1
        data
      end
    end
  end
end
