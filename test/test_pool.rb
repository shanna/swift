require_relative 'helper'

describe 'Adapter' do
  supported_by Swift::DB::Postgres, Swift::DB::Mysql do
    describe 'Asynchronous connection pool' do
      before do
        Swift.db do |db|
          type = db.is_a?(Swift::DB::Postgres) ? 'bytea' : 'blob'
          db.execute %q{drop table if exists users}
          db.execute %Q{create table users(id serial, name text)}
        end
      end

      it 'creates connection pool' do
        driver = Swift.db.kind_of?(Swift::DB::Mysql) ? 'mysql' : 'postgresql'
        assert Swift::Pool.new 5, db: 'swift_test', driver: driver
      end

      describe 'Running queries' do
        it 'should select data' do
          rows = []
          assert Swift.db.write('users', %w{name}, StringIO.new("user1\nuser2\nuser3\n"))
          Swift.pool 5 do |pool|
            pool.execute('select * from users') do |rs|
              rows += rs.to_a
              pool.execute('select * from users') {|rs| rows += rs.to_a }
            end
          end
          assert_equal 6, rows.length
        end
      end
    end
  end
end
