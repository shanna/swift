require 'eventmachine'
require 'swift'

module Swift
  class Adapter
    alias :blocking_execute :execute

    class EMHandler < EM::Connection
      attr_reader :result, :defer
      def initialize result, defer
        @result = result
        @defer  = defer
      end

      def notify_readable
        detach
        begin
          result.retrieve
        rescue Exception => e
          defer.fail(e)
        else
          defer.succeed(result)
        end
      end
    end

    def execute *args
      EM::DefaultDeferrable.new.tap do |defer|
        EM.watch(fileno, EMHandler, async_execute(*args), defer) {|c| c.notify_readable = true }
      end
    end
  end
end
