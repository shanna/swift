require_relative 'helper'
require 'stringio'

describe 'Adapter' do
  supported_by Swift::DB::Postgres, Swift::DB::Mysql, Swift::DB::Sqlite3 do
    describe 'db' do
      before do
        @db = Swift.db
        @db.execute('drop table if exists users')
        serial = case @db
          when Swift::DB::Sqlite3 then 'integer primary key'
          else 'serial'
        end
        @db.execute %Q{create table users(id #{serial}, name text, email text, created_at timestamp)}
      end

      it 'yields db to block' do
        Swift.db do |db|
          assert_kind_of Swift::Adapter, db
        end
      end

      describe 'execute' do
        it 'executes without bind values' do
          assert @db.execute %q{select count(*) from users}
        end

        it 'executes with bind values' do
          assert @db.execute 'insert into users (name, created_at) values (?, current_timestamp)', 'Benny Arthurton'
        end
      end

      describe 'prepared statements' do
        it 'executes via Statement#new' do
          result = []
          Swift::Statement.new(@db, 'select count(*) as n from users').execute {|r| result << r[:n] }
          assert_kind_of Numeric, result[0]
        end

        it 'executes without bind values' do
          assert @db.prepare(%q{insert into users (name) values ('Apple Arthurton')}).execute
        end

        it 'executes with bind values' do
          assert @db.prepare(%q{insert into users (name) values (?)}).execute('Apple Arthurton')
        end

        it 'executes multiple times' do
          sth = @db.prepare(%q{insert into users (name, created_at) values (?, current_timestamp)})
          assert sth.execute('Apple Arthurton')
          assert sth.execute('Benny Arthurton')
        end

        it 'has insert_id' do
          sql = case @db
            when Swift::DB::Postgres then %q{insert into users (name) values (?) returning id}
            else %q{insert into users (name) values (?)}
          end
          assert_kind_of Numeric, @db.prepare(sql).execute('Connie Arthurton').insert_id
        end
      end

      describe 'executed prepared statements' do
        before do
          insert = @db.prepare(%q{insert into users (name, created_at) values (?, current_timestamp)})
          insert.execute('Apple Arthurton')
          insert.execute('Benny Arthurton')
          @sth = @db.prepare('select * from users')
          @res = @sth.execute
        end

        it 'enumerates' do
          assert_kind_of Enumerable, @res
        end

        it 'enumerates block' do
          begin
            @sth.execute{|row| row}
          rescue => error
            flunk error.message
          else
            pass
          end
        end

        it 'returns hash tuples for enumerable methods' do
          assert_kind_of Hash, @res.first
        end

        it 'returns a result set on Adapter#execute{}' do
          @db.execute('select * from users') {|r| assert_kind_of Hash, r }
        end

        it 'returns a result set on Adapter#results' do
          assert_kind_of Swift::Result, @db.execute('select * from users')
        end

        it 'returns fields' do
          assert_equal [ :id, :name, :email, :created_at ], @res.fields
        end
      end


      #--
      # TODO: Not sure how I feel about the block in write; feels like it's just there to get around the fields in the
      # argument list. How about write('users', %w{name, email, balance}, data)?
      describe 'bulk writes!' do
        it 'writes from an IO object' do
          data = StringIO.new "Sally Arthurton\tsally@local\nJonas Arthurton\tjonas@local\n"
          assert_equal 2, @db.write('users', %w{name email}, data)
        end

        it 'writes from a string' do
          data = "Sally Arthurton\tsally@local\nJonas Arthurton\tjonas@local\n"
          assert_equal 2, @db.write('users', %w{name email}, data)
        end

        it 'writes with no columns specified' do
          data = "1\tSally Arthurton\tsally@local\t2010-01-01 00:00:00\n"
          assert_equal 1, @db.write('users', [], data)
        end
      end
    end
  end
end
