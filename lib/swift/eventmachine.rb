require 'eventmachine'
require 'swift'

module Swift
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
