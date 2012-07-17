require_relative 'helper'

describe 'Adapter' do
  supported_by Swift::Adapter::Postgres, Swift::Adapter::Mysql do
    describe 'async operations' do
      it 'can runs queries async' do
        rows = []
        pool = 3.times.map.with_index {|n| Swift.setup n, Swift.db.class, db: 'swift_test' }
        func = case Swift.db
          when Swift::Adapter::Mysql    then 'sleep'
          when Swift::Adapter::Postgres then 'pg_sleep'
        end

        3.times do |n|
          Thread.new do
            pool[n].query("select #{func}(#{(3 - n) / 10.0}), #{n + 1} as query_id") {|row| rows << row[:query_id]}
          end
        end

        Thread.list.reject {|thread| Thread.current == thread}.each(&:join)
        assert_equal [3, 2, 1], rows
      end
    end
  end
end
