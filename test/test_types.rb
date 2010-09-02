require_relative 'helper'

describe 'Adapter' do
  supported_by Swift::DB::Postgres, Swift::DB::Mysql do
    describe 'typecasting' do
      before do
        @db = Swift.db
        @db.execute %q{drop table if exists users}
        @db.execute %q{
          create table users(id serial, name text, age integer, height float, hacker bool, slacker bool, created date)
        }
      end

      it 'query result is typecast correctly' do
        bind = [ 'jim', 32, 178.71, true, false ]
        @db.execute %q{insert into users(name,age,height,hacker,slacker, created) values(?, ?, ?, ?, ?, now())}, *bind

        result = @db.prepare(%q{select * from users limit 1}).execute.first
        assert_kind_of Integer,    result[:id]
        assert_kind_of String,     result[:name]
        assert_kind_of Integer,    result[:age]
        assert_kind_of Float,      result[:height]
        assert_kind_of TrueClass,  result[:hacker]
        assert_kind_of FalseClass, result[:slacker]
        assert_kind_of Date,       result[:created]
      end
    end
  end
end
