require 'swift/adapter/postgres'
require 'swift/adapter/eventmachine'

# TODO: use Module#prepend when backported
module Swift
  class Adapter
    class Eventmachine::Postgres < Postgres
      include Eventmachine
    end # Eventmachine::Postgres
  end # Adapter
end # Swift
