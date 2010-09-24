# Extension.
require_relative '../ext/swift'
require_relative 'swift/adapter'
require_relative 'swift/attribute'
require_relative 'swift/db'
require_relative 'swift/header'
require_relative 'swift/scheme'
require_relative 'swift/type'

# = Swift
# A rational rudimentary object relational mapper.
#
# == Synopsis
#   require 'swift'
#   require 'swift/migrations'
#
#   Swift.trace true # Debugging.
#   Swift.setup :default, Swift::DB::Postgres, db: 'swift'
#
#   class User < Swift::Scheme
#     store     :users
#     attribute :id,    Swift::Type::Integer, serial: true, key: true
#     attribute :name,  Swift::Type::String
#     attribute :email, Swift::Type::String
#   end # User
#
#   # Migrate it.
#   User.migrate!
#
#   # Create
#   User.create name: 'Apple Arthurton', email: 'apple@arthurton.local' # => User
#
#   # Get by key.
#   user = User.get id: 1
#
#   # Alter attribute and update in one.
#   user.update name: 'Jimmy Arthurton'
#
#   # Alter attributes and update.
#   user.name = 'Apple Arthurton'
#   user.update
#
#   # Destroy
#   user.destroy
#
# == See
# * README.rdoc has more usage examples.
# * API.rdoc is a public API overview.
module Swift
  class << self

    # Setup a new DB connection.
    #
    # ==== Notes
    # You almost certainly want to setup a :default named adapter. The :default scope will be used for unscoped
    # calls to Swift.db.
    #
    # ==== Example
    #   Swift.setup :default, Swift::DB::Postgres, db: 'db1'
    #   Swift.setup :other,   Swift::DB::Postgres, db: 'db2'
    #
    # ==== Parameters
    # name<Symbol>::         Adapter name.
    # type<Swift::Adapter>:: Adapter subclass. Swift::DB::* module houses concrete adapters.
    # options<Hash>::        Connection options (:db, :user, :password, :host, :port, :timezone)
    #
    # ==== Returns
    # Swift::Adapter:: Adapter instance.
    #
    # ==== See
    # * Swift::DB for list of of concrete adapters.
    # * Swift::Adapter for connection options.
    def setup name, type, options = {}
      unless type.kind_of?(Class) && type < Swift::Adapter
        raise TypeError, "Expected +type+ Swift::Adapter subclass but got #{type.inspect}"
      end
      (@repositories ||= {})[name] = type.new(options)
    end

    # Fetch or scope a block to a specific DB by name.
    #
    # ==== Example
    #   Swift.db :other do |other|
    #     # Inside this block all these are the same:
    #     # other
    #     # Swift.db
    #     # Swift.db :other
    #
    #     other_users = User.prepare('select * from users where age > ?')
    #     other_users.execute(32)
    #   end
    #
    # ==== Parameters
    # name<Symbol>:: Adapter name.
    # block<Proc>::  Scope this block to the named adapter instead of :default.
    #
    # ==== Returns
    # Swift::Adapter
    #--
    # I pilfered the logic from DM but I don't really understand what is/isn't thread safe.
    def db name = nil, &block
      scopes     = (Thread.current[:swift_db] ||= [])
      repository = if name || scopes.empty?
        @repositories[name || :default] or raise "Unknown db '#{name || :default}', did you forget to #setup?"
      else
        scopes.last
      end

      if block_given?
        begin
          scopes.push(repository)
          block.call(repository)
        ensure
          scopes.pop
        end
      end
      repository
    end

    # List of known Swift::Schema classes.
    #
    # ==== Notes
    # Handy if you are brewing stuff like migrations and need a list of defined schema subclasses.
    #
    # ==== Returns
    # Array<Swift::Schema, ...>
    def schema
      @schema ||= []
    end
  end
end # Swift
