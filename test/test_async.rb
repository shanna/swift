require_relative 'helper'

describe 'Adapter' do
  supported_by Swift::DB::Postgres do
    describe 'async operations' do
      it 'can runs queries async' do
        rows = []
        pool = 3.times.map.with_index {|n| Swift.setup n, Swift::DB::Postgres, db: 'swift' }

        Thread.new do
          pool[0].aexecute('select pg_sleep(0.3), 1 as query_id') {|row| rows << row[:query_id]}
        end

        Thread.new do
          pool[1].aexecute('select pg_sleep(0.2), 2 as query_id') {|row| rows << row[:query_id]}
        end

        Thread.new do
          pool[2].aexecute('select pg_sleep(0.1), 3 as query_id') {|row| rows << row[:query_id]}
        end

        Thread.list.reject {|thread| Thread.current == thread}.each(&:join)

        assert_equal [3, 2, 1], rows
      end
    end
  end
end
