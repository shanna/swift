# try to require home_run in older rubies
unless %r{^1\.9\.[3-9]|^2\.}.match(RUBY_VERSION)
  begin
    require 'home_run'
  rescue LoadError => e
    warn "WARNING: DateTime parsing will be slow without home_run gem on Rubies older than 1.9.3"
  end
end

# Extension.
require_relative 'swift/adapter'
require_relative 'swift/adapter/sql'
require_relative 'swift/attribute'
require_relative 'swift/header'
require_relative 'swift/record'
require_relative 'swift/type'

# A rational rudimentary object relational mapper.
#
# == Synopsis
#   require 'swift'
#   require 'swift/migrations'
#
#   Swift.trace true # Debugging.
#   Swift.setup :default, Swift::DB::Postgres, db: 'swift'
#
#   class User < Swift::Record
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
#   user.delete
#
# == See
# * README.rdoc has more usage examples.
# * API.rdoc is a public API overview.
module Swift
  class << self

    # Setup a new DB connection.
    #
    # You almost certainly want to setup a <tt>:default</tt> named adapter. The <tt>:default</tt> scope will be used
    # for unscoped calls to <tt>Swift.db</tt>.
    #
    # @example
    #   Swift.setup :default, Swift::DB::Postgres, db: 'db1'
    #   Swift.setup :other,   Swift::DB::Postgres, db: 'db2'
    #
    # @param  [Symbol]         name    Adapter name.
    # @param  [Swift::Adapter] type    Concrete adapter subclass. See Swift::DB
    # @param  [Hash]           options Connection options
    # @option options [String]  :db       Name.
    # @option options [String]  :user     (*nix login user)
    # @option options [String]  :password ('')
    # @option options [String]  :host     ('localhost')
    # @option options [Integer] :port     (DB default)
    # @return [Swift::Adapter]
    #
    # @see Swift::DB
    # @see Swift::Adapter
    def setup name, type, options = {}
      unless type.kind_of?(Class) && type < Swift::Adapter
        raise TypeError, "Expected +type+ Swift::Adapter subclass but got #{type.inspect}"
      end
      (@repositories ||= {})[name] = type.new(options)
    end

    # Fetch or scope a block to a specific DB by name.
    #
    # @example
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
    # @param  [Symbol] name     Adapter name.
    # @param  [Proc]   block    Scope this block to the named adapter instead of <tt>:default</tt>.
    # @return [Swift::Adapter]
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
    # Handy if you are brewing stuff like migrations and need a list of defined schema subclasses.
    #
    # @return [Array<Swift::Schema>]
    def schema
      @schema ||= []
    end

    def trace io = $stdout, &block
      Swift.db.trace(io, &block)
    end
  end
end # Swift
