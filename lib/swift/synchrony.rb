require 'em-synchrony'
require 'swift/eventmachine'

module Swift
  class Adapter
    alias :aexecute :execute
    def execute *args
      res = EM::Synchrony.sync aexecute(*args)
      raise res if res.kind_of?(Error)
      yield res if block_given?
      res
    rescue => e
      $stderr.puts e, e.backtrace.join($/)
      nil
    end
  end
end
