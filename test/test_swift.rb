require 'tempfile'
require_relative 'helper'

describe 'Swift' do
  supported_by Swift::DB::Sqlite3 do
    describe 'Trace' do
      before do
        Swift.trace(false)
        @file = Tempfile.new('swift-test')
      end

      after do
        @file.unlink
      end

      it 'should trace commands' do
        sql = 'create table users (id integer, name text)'
        Swift.trace(true, @file)
        Swift.db.execute(sql)

        log = @file.rewind && @file.read
        assert_match sql, log
      end

      it 'should trace commands in block form' do
        sql1 = 'create table users (id integer, name text)'
        sql2 = 'drop table users'

        res = Swift.trace(true, @file) { Swift.db.execute(sql1) && 'foobar' }
        assert_equal 'foobar', res

        Swift.db.execute(sql2)

        log = @file.rewind && @file.read
        assert_match sql1, log
        refute_match sql2, log
      end

      it 'should trace commands in block form and preserve state' do
        sql1 = 'create table users (id integer, name text)'
        sql2 = 'drop table users'

        Swift.trace(true, @file)

        Swift.trace(false) do
          Swift.db.execute(sql1)
        end

        Swift.db.execute(sql2)

        log = @file.rewind && @file.read
        refute_match sql1, log
        assert_match sql2, log
      end

      it 'should cascade exceptions in block form trace' do
        sql1 = 'create table users (id integer, name text)'

        assert_raises(RuntimeError) do
          Swift.trace(true, @file) do
            Swift.db.execute(sql1)
            raise "foo"
          end
        end

        log = @file.rewind && @file.read
        assert_match sql1, log
      end
    end
  end
end
