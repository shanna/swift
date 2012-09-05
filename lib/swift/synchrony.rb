require 'em-synchrony'
require 'swift/eventmachine'

module Swift
  # em-synchrony support for Swift::Adapter
  #
  # This replaces the default Adapter#execute with a version that uses EM::Synchrony.sync to wait for the
  # defered command to complete. It assumes that the execute method is called inside a em-synchrony Fiber.
  class Adapter
    alias :aexecute :execute

    # Execute a command asynchronously and pause the Fiber until the command finishes.
    #
    # @example
    #   EM.run do
    #     3.times.each do |n|
    #       EM.synchrony do
    #         db     = Swift.setup(:default, Swift::Adapter::Postgres, db: "swift_test")
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
      res = EM::Synchrony.sync aexecute(*args)
      raise res if res.kind_of?(Error)
      yield res if block_given?
      res
    end
  end
end
