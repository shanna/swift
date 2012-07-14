require_relative 'helper'

describe 'Error' do
  supported_by Swift::Adapter::Postgres, Swift::Adapter::Mysql, Swift::Adapter::Sqlite3 do
    describe 'prepare' do
      before do
        Swift.db do |db|
          db.execute %q{drop table if exists users}
          db.execute %q{create table users(id integer, name text, primary key(id))}
        end
      end

      it 'throws a runtime error on invalid sql' do
        assert_raises(Swift::RuntimeError) do
          Swift.db.prepare('garble garble garble')
        end
      end

      it 'throws a runtime error on invalid bind parameters' do
        assert_raises(Swift::ArgumentError) do
          Swift.db.prepare('select * from users where id > ?').execute
        end
      end
    end
  end

  supported_by Swift::Adapter::Postgres do
    describe 'execute' do
      before do
        Swift.db do |db|
          db.execute %q{drop table if exists users}
          db.execute %q{create table users(id integer, name text, primary key(id))}
        end
      end

      it 'throws connection error on connection failures' do
        select1 = Swift.db.prepare("select * from users")
        select2 = Swift.db.prepare("select * from users where id > ?")

        Swift.db.close

        assert_raises(Swift::ConnectionError) { select1.execute }
        assert_raises(Swift::ConnectionError) { select2.execute(1) }
        assert_raises(Swift::ConnectionError) { Swift.db.execute("select * from users") }
        assert_raises(Swift::ConnectionError) { Swift.db.execute("select * from users where id > ?", 1) }
      end
    end
  end
end
