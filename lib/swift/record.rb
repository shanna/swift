module Swift

  # A resource (instance) definition.
  #
  # @example A user record.
  #   class User < Swift::Record
  #     store     :users
  #     attribute :id,         Swift::Type::Integer, serial: true, key: true
  #     attribute :name,       Swift::Type::String
  #     attribute :email,      Swift::Type::String
  #     attribute :updated_at, Swift::Type::Time
  #   end # User
  class Record
    attr_accessor :tuple
    alias_method :record, :class

    # @example
    #   User.new(
    #     name:       'Apple Arthurton',
    #     email:      'apple@arthurton.local',
    #     updated_at: Time.now
    #   )
    # @param [Hash] options Create resource and set attributes. <tt>{name: value}</tt>
    def initialize options = {}
      @tuple = record.header.new_tuple
      options.each{|k, v| public_send(:"#{k}=", v)}
    end

    # @example
    #   apple = User.create(
    #     name:       'Apple Arthurton',
    #     email:      'apple@arthurton.local',
    #     updated_at: Time.now
    #   )
    #   apple.update(name: 'Arthur Appleton')
    #
    # @param [Hash] options Update attributes. <tt>{name: value}</tt>
    def update options = {}
      options.each{|k, v| public_send(:"#{k}=", v)}
      Swift.db.update(record, self)
    end

    # @example
    #   apple = User.create(
    #     name:       'Apple Arthurton',
    #     email:      'apple@arthurton.local',
    #     updated_at: Time.now
    #   )
    #   apple.delete
    def delete resources = self
      Swift.db.delete(record, resources)
    end

    class << self
      # Attribute set.
      #
      # @return [Swift::Header]
      attr_accessor :header

      def inherited klass
        klass.header = Header.new
        klass.header.push(*header) if header
        klass.store store          if store
        Swift.schema.push(klass)   if klass.name
      end

      def load tuple
        record       = allocate
        record.tuple = tuple
        record
      end

      # Define a new attribute for this record.
      #
      # @see Swift::Attribute#new
      def attribute name, type, options = {}
        header.push(attribute = type.new(self, name, options))
        define_singleton_method(name, lambda{ attribute })
      end

      # Define the store (table).
      #
      # @param  [Symbol] name Storage name.
      # @return [Symbol]
      def store name = nil
        name ? @store = name : @store
      end

      # Store (table) name.
      #
      # @return [String]
      def to_s
        store.to_s
      end

      # Create (insert).
      #
      # @example
      #   apple = User.create(
      #     name:       'Apple Arthurton',
      #     email:      'apple@arthurton.local',
      #     updated_at: Time.now
      #   )
      #
      # @param [Hash, Array<Hash>] resources Create with attributes. <tt>{name: value}</tt>
      def create resources = {}
        Swift.db.create(self, resources)
      end

      # Select by id(s).
      #
      # @example Single key.
      #   User.get(id: 12)
      # @example Complex primary key.
      #   UserAddress.get(user_id: 12, address_id: 15)
      #
      # @param  [Hash] keys Hash of id(s) <tt>{id_name: value}</tt>.
      # @return [Swift::Record, nil]
      def get keys
        Swift.db.get(self, keys)
      end

      # Prepare a statement for on or more executions.
      #
      # @example
      #   sth = User.prepare("select * from #{User} where #{User.name} = ?")
      #   sth.execute('apple') #=> Result
      #   sth.execute('benny') #=> Result
      #
      # @param  [String] statement Query statement.
      # @return [Swift::Statement]
      def prepare statement = ''
        Swift.db.prepare(self, statement)
      end

      # Execute a single statement.
      #
      # @example
      #   result = User.execute("select * from #{User} where #{User.name} = ?", 'apple')
      #   sth.first # User object.
      #
      # @param  [String]  statement Query statement.
      # @param  [*Object] binds     Bind values.
      # @yield  [Swift::Result]
      # @return [Swift::Result]
      def execute statement = '', *binds
        Swift.db.prepare(self, statement, *binds)
        Swift::Result.new(self, Swift.db.execute(statement, *binds))
      end
    end
  end # Record
end # Swift
