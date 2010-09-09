require_relative 'helper'
require 'swift/pool'

describe 'Adapter' do
  supported_by Swift::DB::Postgres, Swift::DB::Mysql, Swift::DB::DB2 do
    describe 'Asynchronous connection pool' do
      before do
        Swift.db do |db|
          db.execute %q{drop table users} rescue nil
          db.execute %Q{create table users(name varchar(64))}
        end
      end

      it 'creates connection pool and runs queries' do
        rows = []
        Swift.pool(5) do |pool|
          assert pool
          assert Swift.db.write('users', %w{name}, StringIO.new("user1\nuser2\nuser3\n"))
          pool.execute('select * from users') do |rs|
            rows += rs.to_a
            Thread.new do
              sleep 0.25
              pool.execute('select * from users order by name desc') {|rs| rows += rs.to_a; EM.stop }
            end
          end
          pool.execute('select * from users') do |rs|
            rows += rs.to_a
          end
        end

        data = %w(user1 user2 user3)

        assert_equal 9, rows.length
        assert_equal data*2 + data.reverse, rows.map {|r| r[:name] }
      end
    end
  end
end
