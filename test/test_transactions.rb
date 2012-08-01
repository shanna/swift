require_relative 'helper'

describe 'Adapter' do
  supported_by Swift::Adapter::Postgres, Swift::Adapter::Mysql, Swift::Adapter::Sqlite3 do
    describe 'transactions' do
      before do
        @name = 'test1 - transaction 1'
        @db   = Swift.db
        @db.execute %q{drop table if exists users}
        @db.execute %q{create table users(name text, created_at timestamp)}

        # In case of MyISAM default.
        @db.kind_of?(Swift::Adapter::Mysql) && @db.execute('alter table users engine=innodb')

        @sth = @db.prepare('select count(*) as c from users where name = ?')
      end

      it 'yields db to block' do
        @db.transaction do |db|
          assert_kind_of Swift::Adapter, db
        end

        @db.transaction :sweet do |db|
          assert_kind_of Swift::Adapter, db
        end
      end

      it 'should return result from block' do
        assert_equal :foobar, @db.transaction {|db| foobar = 1; foobar = :foobar }
      end

      describe 'commits work' do
        before do
          @db.execute('delete from users')
        end

        after do
          assert_equal 1, @sth.execute(@name).first[:c]
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
      end # commits work

      describe 'rollbacks work' do
        before do
          @db.execute('delete from users')
        end

        after do
          assert_equal 0, @sth.execute(@name).first[:c]
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
      end # rollbacks work

      describe 'nested transactions' do
        before do
          @db.execute('delete from users')
        end

        after do
          assert_equal 1, @sth.execute(@name).first[:c]
        end

        it 'should autocommit and autorollback' do
          @db.transaction do |db|
            db.execute('insert into users(name) values(?)', @name)
            begin
              db.transaction do
                db.execute('insert into users(name) values(?)', @name)
                raise 'foo'
              end
            rescue RuntimeError
            end
          end
        end
      end # nested transactions

    end # transactions
  end # supported_by
end # adapter
