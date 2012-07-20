require 'eventmachine'
require 'swift'

module Swift
  # Eventmachine Adapter Extensions.
  #
  # This replaces the Adapter#execute method with a non-blocking asynchronous version.
  class Adapter
    alias :blocking_execute :execute

    class EMHandler < EM::Connection
      def initialize adapter, record, defer
        @adapter = adapter
        @record  = record
        @defer   = defer
      end

      def notify_readable
        detach
        begin
          @defer.succeed(@record ? Result.new(@record, @adapter.result) : @adapter.result)
        rescue Exception => e
          @defer.fail(e)
        end
      end
    end

    # Execute a command asynchronously.
    #
    # @example
    #   defer = Swift.db.execute(User, "select * from users where id = ?", 1)
    #   defer.callback do |user|
    #     p user.id
    #   end
    #   defer.errback do |error|
    #     p error
    #   end
    #
    # @see  [Swift::Adapter]
    def execute command, *bind
      start = Time.now
      record, command = command, bind.shift if command.kind_of?(Class) && command < Record
      query(command, *bind)
      EM::DefaultDeferrable.new.tap do |defer|
        EM.watch(fileno, EMHandler, self, record, defer) {|c| c.notify_readable = true }
      end
    end
  end
end
