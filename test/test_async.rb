require_relative 'helper'

describe 'Adapter' do
# TODO
# supported_by Swift::Adapter::Postgres do
#   describe 'async operations' do
#     it 'can runs queries async' do
#       rows = []
#       pool = 3.times.map.with_index {|n| Swift.setup n, Swift::Adapter::Postgres, db: 'swift_test' }

#       Thread.new do
#         pool[0].async_execute('select pg_sleep(0.3), 1 as query_id') {|row| rows << row[:query_id]}
#       end

#       Thread.new do
#         pool[1].async_execute('select pg_sleep(0.2), 2 as query_id') {|row| rows << row[:query_id]}
#       end

#       Thread.new do
#         pool[2].async_execute('select pg_sleep(0.1), 3 as query_id') {|row| rows << row[:query_id]}
#       end

#       Thread.list.reject {|thread| Thread.current == thread}.each(&:join)

#       assert_equal [3, 2, 1], rows
#     end
#   end
# end
end
