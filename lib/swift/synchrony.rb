require 'em-synchrony'
require 'swift/eventmachine'

module Swift
  class Adapter
    alias :aexecute :execute
    def execute *args
      res = EM::Synchrony.sync aexecute(*args)
      raise res if res.kind_of?(SwiftError)
      yield res if block_given?
      res
    end
  end
end
