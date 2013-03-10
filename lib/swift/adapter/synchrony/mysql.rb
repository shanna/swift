require 'swift/adapter/synchrony'
require 'swift/adapter/em/mysql'

module Swift
  # em-synchrony support for Swift::Adapter
  #
  class Adapter
    class Synchrony::Mysql < EM::Mysql
      include Synchrony
    end # Synchrony::Mysql
  end # Adapter
end # Swift
