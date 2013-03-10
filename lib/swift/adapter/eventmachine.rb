require 'eventmachine'
require 'swift'

module Swift
  # Eventmachine Adapter Extensions.
  #
  # This replaces the Adapter#execute method with a non-blocking asynchronous version.
  class Adapter
    module Eventmachine
      class Handler < EM::Connection
        def initialize adapter, record, defer
          @started = Time.now
          @adapter = adapter
          @record  = record
          @defer   = defer
        end

        def notify_readable
          detach
          start, command, bind = @adapter.pending.shift
          @adapter.log_command(start, command, bind) if @adapter.trace?

          begin
            @defer.succeed(@record ? Result.new(@record, @adapter.result) : @adapter.result)
          rescue Exception => e
            @defer.fail(e)
          end
        end
      end # Handler

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
        raise RuntimeError, 'Command already in progress' unless pending.empty?

        record, command = command, bind.shift if command.kind_of?(Class) && command < Record
        pending << [Time.now, command, bind]
        query(command, *bind)

        ::EM::DefaultDeferrable.new.tap do |defer|
          ::EM.watch(fileno, Handler, self, record, defer) {|c| c.notify_readable = true}
        end
      end

      def pending
        @pending ||= []
      end
    end # Eventmachine

    EM = Eventmachine
  end # Adapter
end # Swift
