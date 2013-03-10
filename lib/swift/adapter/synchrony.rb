require 'em-synchrony'

module Swift
  # em-synchrony support for Swift::Adapter
  #
  class Adapter
    module Synchrony
      # Execute a command asynchronously and pause the Fiber until the command finishes.
      #
      # @example
      #   EM.run do
      #     3.times.each do |n|
      #       EM.synchrony do
      #         db     = Swift.setup(:default, Swift::Adapter::Synchrony::Postgres, db: "swift_test")
      #         result = db.execute("select pg_sleep(3 - #{n}), #{n + 1} as qid")
      #
      #         p result.first
      #         EM.stop if n == 0
      #       end
      #     end
      #   end
      #
      # @see [Swift::Adapter]
      def execute *args
        res = ::EM::Synchrony.sync super(*args)
        if res.kind_of?(Error)
          res.set_backtrace caller.reject {|subject| subject =~ %r{swift/fiber_connection_pool}}
          raise res
        end
        yield res if block_given?
        res
      end

      def transaction &block
        Swift.scopes.push(self)
        execute('begin')
        res = yield(self)
        execute('commit')
        res
      rescue => e
        execute('rollback')
        raise e
      ensure
        Swift.scopes.pop
      end
    end # Synchrony
  end # Adapter
end # Swift
