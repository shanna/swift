require_relative 'helper'

describe 'Adapter' do
  supported_by Swift::DB::Postgres, Swift::DB::Mysql, Swift::DB::DB2 do
    describe 'transactions' do
      before do
        @name = 'test1 - transaction 1'
        @db   = Swift.db
        @db.execute %q{drop table users} rescue nil
        @db.execute %q{create table users(name varchar(512), created_at timestamp)}
        @db.execute %q{alter table users engine=innodb} if @db.kind_of?(Swift::DB::Mysql) # In case of MyISAM default.
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

      describe 'commits work' do
        before do
          @db.execute('truncate users')
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
          @db.execute('truncate users')
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
          @db.execute('truncate users')
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
