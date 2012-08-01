require_relative 'helper'

describe 'Swift' do
  supported_by Swift::Adapter::Sqlite3 do
    describe 'Trace' do
      it 'should trace commands' do
        sql = 'create table users (id integer, name text)'
        io  = StringIO.new

        Swift.trace(io) do
          Swift.db.execute(sql)
        end

        assert_match sql, io.rewind && io.read
      end

      it 'should cascade exceptions in trace' do
        sql = 'create table users (id integer, name text)'

        assert_raises(RuntimeError) do
          Swift.trace(StringIO.new) do
            Swift.db.execute(sql)
            raise "foo"
          end
        end
      end
    end
  end
end
