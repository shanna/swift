require_relative 'helper'

describe 'Adapter' do
  supported_by :Postgres, :Mysql do
    describe 'execute' do
      it 'executes without bind values' do
        assert Swift.db.execute %q{drop table if exists users}
      end

      it 'executes with bind values' do
        Swift.db.execute %q{drop table if exists users}
        Swift.db.execute %q{create table users(id serial, name text, created_at timestamp)}
        assert Swift.db.execute 'insert into users (name, created_at) values (?, now())', 'Benny Arthurton'
      end
    end

    describe 'prepared statements' do
      before do
        @db = Swift.db do
          execute %q{drop table if exists users}
          execute %q{create table users(id serial, name text, created_at timestamp)}
        end
      end

      it 'executes without bind values' do
        assert @db.prepare(%q{insert into users (name, created_at) values ('Apple Arthurton', now())}).execute
      end

      it 'executes with bind values' do
        assert @db.prepare(%q{insert into users (name, created_at) values (?, now())}).execute('Apple Arthurton')
      end

      it 'executes multiple times' do
        sth = @db.prepare(%q{insert into users (name, created_at) values (?, now())})
        assert sth.execute('Apple Arthurton')
        assert sth.execute('Benny Arthurton')
      end
    end

    describe 'executed prepared statements' do
      before do
        @db = Swift.db do
          execute %q{drop table if exists users}
          execute %q{create table users(id serial, name text, created_at timestamp)}
          sth = prepare(%q{insert into users (name, created_at) values (?, now())})
          sth.execute('Apple Arthurton')
          sth.execute('Benny Arthurton')
        end
        @sth = @db.prepare('select * from users').execute
      end

      it 'enumerates' do
        assert_kind_of Enumerable, @sth
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
        assert_kind_of Hash, @sth.first
      end

      it 'returns array rows for fetchrow' do
        assert_kind_of Array, @sth.fetchrow
      end
    end

    #--
    # TODO:
    # describe 'transactions'
    #   it 'has vanilla transactions'
    #   it 'has named save points'
    # describe 'write'
  end
end
