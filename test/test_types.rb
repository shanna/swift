require_relative 'helper'

describe 'Adapter' do
  supported_by Swift::DB::Postgres, Swift::DB::Mysql do
    describe 'typecasting' do
      before do
        @db = Swift.db
        @db.execute %q{drop table if exists users}
        @db.execute %q{
          create table users(
            id      serial,
            name    text,
            age     integer,
            height  float,
            hacker  bool,
            slacker bool,
            created date,
            updated timestamp
          )
        }
      end

      it 'query result is typecast correctly' do
        bind = [ 1, 'jim', 32, 178.71, true, false, '2010-01-02', '2010-01-01 23:22:21.012345' ]
        @db.execute %q{insert into users values(?, ?, ?, ?, ?, ?, ?, ?)}, *bind

        result = @db.prepare(%q{select * from users limit 1}).execute.first
        assert_kind_of Integer,    result[:id]
        assert_kind_of String,     result[:name]
        assert_kind_of Integer,    result[:age]
        assert_kind_of Float,      result[:height]
        assert_kind_of TrueClass,  result[:hacker]
        assert_kind_of FalseClass, result[:slacker]
        assert_kind_of Date,       result[:created]
        assert_kind_of Time,       result[:updated]

        assert_equal   12345,      result[:updated].usec if @db.kind_of?(Swift::DB::Postgres)
      end
    end
  end
end
