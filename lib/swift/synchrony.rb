require 'em-synchrony'
require 'swift/eventmachine'

module Swift
  class Adapter
    alias :aexecute :execute
    def execute *args
      EM::Synchrony.sync aexecute(*args)
    end
  end
end
