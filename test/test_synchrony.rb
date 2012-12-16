require 'helper'

describe 'fiber connection pool' do
  before do
    skip 'swift/synchrony re-defines Adapter#execute' unless ENV['TEST_SWIFT_SYNCHRONY']

    require 'swift/fiber_connection_pool'
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
      EM.stop
    end
  end

  it 'can synchronize queries across fibers' do
    EM.run do
      Swift.setup_connection_pool 2, :default, Swift::Adapter::Postgres, db: 'swift_test'

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
      Swift.setup_connection_pool 2, :default, Swift::Adapter::Postgres, db: 'swift_test'

      begin
        Swift.db.execute 'foo bar baz'
      rescue => e
        error = e
      end

      assert error
      assert_match %r{test/test_synchrony.rb:48}, error.backtrace.first
      EM.stop
    end
  end
end
