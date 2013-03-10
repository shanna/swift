require 'swift/adapter/synchrony'
require 'swift/adapter/em/postgres'

module Swift
  # em-synchrony support for Swift::Adapter
  #
  class Adapter
    class Synchrony::Postgres < EM::Postgres
      include Synchrony
    end # Synchrony::Postgres
  end # Adapter
end # Swift
