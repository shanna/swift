require 'swift/adapter/mysql'
require 'swift/adapter/eventmachine'

# TODO: use Module#prepend when backported
module Swift
  class Adapter
    class Eventmachine::Mysql < Mysql
      include Eventmachine
    end # Eventmachine::Mysql
  end # Adapter
end # Swift
