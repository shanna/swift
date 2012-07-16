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

    def prepare record = nil, command
      record ? Statement.new(record, command) : db.prepare(command)
    end

    def trace io = $stdout
      @trace = io
      yield
      @trace = false
    end

    def execute command, *bind
      start = Time.now
      record, command = command, bind.shift if command.kind_of?(Class) && command < Record
      record ? Result.new(record, db.execute(command, *bind)) : db.execute(command, *bind)
    ensure
      @trace.print Time.now.strftime('%F %T.%N'), ' - ', (Time.now - start).to_f, ' - ', command, ' ', bind, $/ if @trace
    end
  end # Adapter
end # Swift
