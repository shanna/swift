require 'swift/result'
require 'swift/statement'

module Swift

  # Adapter.
  #
  # @abstract
  # @see      Swift::DB See Swift::DB for concrete adapters.
  class Adapter
    attr_reader :db

    def initialize db
      @db = db
    end

    # Select by id(s).
    #
    # @example Single key.
    #   Swift.db.get(User, id: 12)
    # @example Complex primary key.
    #   Swift.db.get(UserAddress, user_id: 12, address_id: 15)
    #
    # @param  [Swift::Record] record Concrete record subclass to load.
    # @param  [Hash]          keys   Hash of id(s) <tt>{id_name: value}</tt>.
    # @return [Swift::Record, nil]
    # @see    Swift::Record.get
    #--
    # NOTE: Not significantly shorter than Record.db.first(User, 'id = ?', 12)
    def get record, keys
      resource = record.new(keys)
      execute(record, command_get(record), *resource.tuple.values_at(*record.header.keys)).first
    end

    # Create one or more.
    #
    # @example Record.
    #   user = User.new(name: 'Apply Arthurton', age: 32)
    #   Swift.db.create(User, user)
    #   #=> Swift::Record
    # @example Coerce hash to record.
    #   Swif.db.create(User, name: 'Apple Arthurton', age: 32)
    #   #=> Swift::Record
    # @example Multiple resources.
    #   apple = User.new(name: 'Apple Arthurton', age: 32)
    #   benny = User.new(name: 'Benny Arthurton', age: 30)
    #   Swift.db.create(User, [apple, benny])
    #   #=> Array<Swift::Record>
    # @example Coerce multiple resources.
    #   Swift.db.create(User, [{name: 'Apple Arthurton', age: 32}, {name: 'Benny Arthurton', age: 30}])
    #   #=> Array<Swift::Record>
    #
    # @param  [Swift::Record]                                   record    Concrete record subclass to load.
    # @param  [Swift::Record, Hash, Array<Swift::Record, Hash>] resources The resources to be saved.
    # @return [Swift::Record, Array<Swift::Record>]
    # @note   Hashes will be coerced into a Swift::Record resource via Swift::Record#new
    # @note   Passing a scalar will result in a scalar.
    # @see    Swift::Record.create
    def create record, resources
      result = [resources].flatten.map do |resource|
        resource = record.new(resource) unless resource.kind_of?(record)
        result   = execute(command_create(record), *resource.tuple.values_at(*record.header.insertable))
        resource.tuple[record.header.serial] = result.insert_id if record.header.serial
        resource
      end
      resources.kind_of?(Array) ? result : result.first
    end

    # Update one or more.
    #
    # @example Record.
    #   user      = Swift.db.create(User, name: 'Apply Arthurton', age: 32)
    #   user.name = 'Arthur Appleton'
    #   Swift.db.update(User, user)
    #   #=> Swift::Record
    # @example Coerce hash to record.
    #   user      = Swift.db.create(User, name: 'Apply Arthurton', age: 32)
    #   user.name = 'Arthur Appleton'
    #   Swif.db.update(User, user.tuple)
    #   #=> Swift::Record
    # @example Multiple resources.
    #   apple = Swift.db.create(User, name: 'Apple Arthurton', age: 32)
    #   benny = Swift.db.create(User, name: 'Benny Arthurton', age: 30)
    #   Swift.db.update(User, [apple, benny])
    #   #=> Array<Swift::Record>
    # @example Coerce multiple resources.
    #   apple = Swift.db.create(User, name: 'Apple Arthurton', age: 32)
    #   benny = Swift.db.create(User, name: 'Benny Arthurton', age: 30)
    #   Swift.db.update(User, [apple.tuple, benny.tuple])
    #   #=> Array<Swift::Record>
    #
    # @param  [Swift::Record]                                   record    Concrete record subclass to load.
    # @param  [Swift::Record, Hash, Array<Swift::Record, Hash>] resources The resources to be updated.
    # @return [Swift::Record, Swift::Result]
    # @note   Hashes will be coerced into a Swift::Record resource via Swift::Record#new
    # @note   Passing a scalar will result in a scalar.
    # @see    Swift::Record#update
    def update record, resources
      result = [resources].flatten.map do |resource|
        resource = record.new(resource) unless resource.kind_of?(record)
        keys     = resource.tuple.values_at(*record.header.keys)

        # TODO: Name the key field(s) missing.
        raise ArgumentError, "#{record} resource has incomplete key: #{resource.inspect}" \
          unless keys.select(&:nil?).empty?

        execute(command_update(record), *resource.tuple.values_at(*record.header.updatable), *keys)
        resource
      end
      resources.kind_of?(Array) ? result : result.first
    end

    # Delete one or more.
    #
    # @example Record.
    #   user      = Swift.db.create(User, name: 'Apply Arthurton', age: 32)
    #   user.name = 'Arthur Appleton'
    #   Swift.db.delete(User, user)
    # @example Coerce hash to record.
    #   user      = Swift.db.create(User, name: 'Apply Arthurton', age: 32)
    #   user.name = 'Arthur Appleton'
    #   Swif.db.delete(User, user.tuple)
    # @example Multiple resources.
    #   apple = Swift.db.create(User, name: 'Apple Arthurton', age: 32)
    #   benny = Swift.db.create(User, name: 'Benny Arthurton', age: 30)
    #   Swift.db.delete(User, [apple, benny])
    # @example Coerce multiple resources.
    #   apple = Swift.db.create(User, name: 'Apple Arthurton', age: 32)
    #   benny = Swift.db.create(User, name: 'Benny Arthurton', age: 30)
    #   Swift.db.delete(User, [apple.tuple, benny.tuple])
    #
    # @param  [Swift::Record]                                   record    Concrete record subclass to load.
    # @param  [Swift::Record, Hash, Array<Swift::Record, Hash>] resources The resources to be deleteed.
    # @return [Swift::Record, Array<Swift::Record>]
    # @note   Hashes will be coerced into a Swift::Record resource via Swift::Record#new
    # @note   Passing a scalar will result in a scalar.
    # @see    Swift::Record#delete
    def delete record, resources
      result = [resources].flatten.map do |resource|
        resource = record.new(resource) unless resource.kind_of?(record)
        keys     = resource.tuple.values_at(*record.header.keys)

        # TODO: Name the key field(s) missing.
        raise ArgumentError, "#{record} resource has incomplete key: #{resource.inspect}" \
          unless keys.select(&:nil?).empty?

        if result = execute(command_delete(record), *keys)
          resource.freeze
        end
        result
      end
      resources.kind_of?(Array) ? result : result.first
    end

    # Create a server side prepared statement
    #
    # @example
    #   finder = Swift.db.prepare(User, "select * from users where id > ?")
    #   user   = finder.execute(1).first
    #   user.id
    #
    # @overload prepare(record, command)
    #   @param  [Swift::Record]       record    Concrete record subclass to load.
    #   @param  [String]              command   Command to be prepared by the underlying concrete adapter.
    # @overload prepare(command)
    #   @param  [String]              command   Command to be prepared by the underlying concrete adapter.
    #
    # @return [Swift::Statement, Swift::DB::Mysql::Statement, Swift::DB::Sqlite3::Statement, ...]
    def prepare record = nil, command
      record ? Statement.new(record, command) : db.prepare(command)
    end

    # Trace commands being executed.
    #
    # @example
    #   Swift.db.trace { Swift.db.execute("select * from users") }
    # @example
    #   Swift.db.trace(StringIO.new) { Swift.db.execute("select * from users") }
    # @example
    #   Swift.db.trace(File.open('command.log', 'w')) { Swift.db.execute("select * from users") }
    #
    # @param  [IO]      io      An optional IO object to log commands
    # @return [Object]  result  Result from the block yielded to
    def trace io = $stdout
      @trace = io
      result = yield
      @trace = false
      result
    end

    # Check if the adapter commands are being traced.
    #
    # @return [TrueClass, FalseClass]
    def trace?
      !!@trace
    end

    # Execute a command using the underlying concrete adapter.
    #
    # @example
    #   Swift.db.execute("select * from users")
    # @example
    #   Swift.db.execute(User, "select * from users where id = ?", 1)
    #
    # @overload execute(record, command, *bind)
    #   @param  [Swift::Record]       record    Concrete record subclass to load.
    #   @param  [String]              command   Command to be executed by the adapter.
    #   @param  [*Object]             bind      Bind values.
    # @overload execute(command, *bind)
    #   @param  [String]              command   Command to be executed by the adapter.
    #   @param  [*Object]             bind      Bind values.
    #
    # @return [Swift::Result, Swift::DB::Mysql::Result, Swift::DB::Sqlite3::Result, ...]
    def execute command, *bind
      start = Time.now
      record, command = command, bind.shift if command.kind_of?(Class) && command < Record
      record ? Result.new(record, db.execute(command, *bind)) : db.execute(command, *bind)
    ensure
      log_command(start, command, bind) if @trace
    end

    # :nodoc:
    def log_command start, command, bind
      @trace.print Time.now.strftime('%F %T.%N'), ' - %.9f' % (Time.now - start).to_f, ' - ', command
      @trace.print ' ', bind if bind && bind.size > 0
      @trace.print $/
    end
  end # Adapter
end # Swift
