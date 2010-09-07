require_relative 'helper'
describe 'Adapter' do
  supported_by Swift::DB::Postgres, Swift::DB::Mysql do
    describe 'transactions' do
      before do
        @name = 'test1 - transaction 1'
        @db   = Swift.db
        @db.execute %q{drop table if exists users}
        @db.execute %q{create table users(id serial, name text, created_at timestamp)}
      end

      it 'yields db to block' do
        @db.transaction do |db|
          assert_kind_of Swift::Adapter, db
        end

        @db.transaction :sweet do |db|
          assert_kind_of Swift::Adapter, db
        end
      end

      describe 'commits work' do
        before do
          @db.execute('truncate users')
        end

        after do
          @db.execute('select count(*) as c from users where name = ?', @name) {|r| assert_equal 1, r[:c] }
        end

        it 'should allow explicit commits' do
          @db.transaction do |db|
            db.execute('insert into users(name) values(?)', @name)
            db.commit
          end
        end

        it 'should autocommit' do
          @db.transaction do |db|
            db.execute('insert into users(name) values(?)', @name)
          end
        end
      end

      describe 'rollbacks work' do

        before do
          @db.execute('truncate users')
        end

        after do
          @db.execute('select count(*) as c from users where name = ?', @name) {|r| assert_equal 0, r[:c] }
        end

        it 'should allow explicit rollbacks' do
          @db.transaction do |db|
            db.execute('insert into users(name) values(?)', @name)
            db.rollback
          end
        end

        it 'should auto rollback' do
          assert_raises(RuntimeError) do
            @db.transaction do |db|
              db.execute('insert into users(name) values(?)', @name)
              raise 'foo'
            end
          end
        end
      end
    end
  end
end
