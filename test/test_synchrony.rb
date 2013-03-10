require 'helper'
require 'swift/fiber_connection_pool'
require 'swift/adapter/synchrony/postgres'

describe 'fiber connection pool' do
  before do

    EM.synchrony do
      Swift.setup(:default, Swift::Adapter::Postgres, db: 'swift_test')
      Swift.db.execute('drop table if exists users')
      Swift.db.execute('create table users(id serial primary key, name text)')

      @user = Class.new(Swift::Record) do
        store :users
        attribute :id,   Swift::Type::Integer, key: true, serial: true
        attribute :name, Swift::Type::String
      end

      10.times { @user.create(name: 'test') }

      # async on from now on
      Swift.setup(:default) do
        Swift::FiberConnectionPool.new(size: 2) do
          Swift::Adapter::Synchrony::Postgres.new(db: 'swift_test')
        end
      end
      EM.stop
    end
  end

  it 'can synchronize queries across fibers' do
    EM.run do
      @counts = []
      5.times do
        EM.synchrony do
          @counts << @user.execute('select * from users').selected_rows
        end
      end
      EM.add_timer(0.2) { EM.stop }
    end

    assert_equal 5,    @counts.size
    assert_equal [10], @counts.uniq
  end

  it 'sets appropriate backtrace for errors' do
    EM.synchrony do
      error = nil

      begin
        Swift.db.execute 'foo bar baz'
      rescue => e
        error = e
      end

      assert error
      assert_match %r{test/test_synchrony.rb}, error.backtrace[0]
      EM.stop
    end
  end
end
