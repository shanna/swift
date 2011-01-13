module Swift

  # A resource (instance) definition.
  #
  # @example A user scheme.
  #   class User < Swift::Scheme
  #     store     :users
  #     attribute :id,         Swift::Type::Integer, serial: true, key: true
  #     attribute :name,       Swift::Type::String
  #     attribute :email,      Swift::Type::String
  #     attribute :updated_at, Swift::Type::Time
  #   end # User
  class Scheme
    attr_accessor :tuple
    alias_method :scheme, :class

    # @example
    #   User.new(
    #     name:       'Apple Arthurton',
    #     email:      'apple@arthurton.local',
    #     updated_at: Time.now
    #   )
    # @param [Hash] options Create relation and set attributes. <tt>{name: value}</tt>
    def initialize options = {}
      @tuple = scheme.header.new_tuple
      options.each{|k, v| send(:"#{k}=", v)}
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
      options.each{|k, v| send(:"#{k}=", v)}
      Swift.db.update(scheme, self)
    end

    # @example
    #   apple = User.create(
    #     name:       'Apple Arthurton',
    #     email:      'apple@arthurton.local',
    #     updated_at: Time.now
    #   )
    #   apple.destroy
    def destroy resources = self
      Swift.db.destroy(scheme, resources)
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
        scheme       = allocate
        scheme.tuple = tuple
        scheme
      end

      # Define a new attribute for this scheme.
      #
      # @see Swift::Attribute#new
      def attribute name, type, options = {}
        header.push(attribute = type.new(self, name, options))
        (class << self; self end).send(:define_method, name, lambda{ attribute })
      end

      # Define the store (table).
      #
      # @param  [Symbol] name Storage name.
      # @return [Symbol]
      def store name = nil
        name ? @store = name : @store
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
      # @param [Hash, Array<Hash>] options Create with attributes. <tt>{name: value}</tt>
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
      # @return [Swift::Scheme, nil]
      def get keys
        Swift.db.get(self, keys)
      end

      # Select one or more.
      #
      # @example All.
      #   User.all
      # @example All with conditions and binds.
      #   User.all(':name = ? and :age > ?', 'Apple Arthurton', 32)
      # @example Block form iterator.
      #   User.all(':age > ?', 32) do |user|
      #     puts user.name
      #   end
      #
      # @param  [String]        conditions Optional SQL 'where' fragment.
      # @param  [Object, ...]   *binds     Optional bind values that accompany conditions SQL fragment.
      # @param  [Proc]          &block     Optional 'each' iterator block.
      # @return [Swift::Result]
      def all conditions = '', *binds, &block
        Swift.db.all(self, conditions, *binds, &block)
      end

      # Select one.
      #
      # @example First.
      #   User.first
      # @example First with conditions and binds.
      #   User.first(':name = ? and :age > ?', 'Apple Arthurton', 32)
      # @example Block form iterator.
      #   User.first(User, 'age > ?', 32) do |user|
      #     puts user.name
      #   end
      #
      # @param  [String]        conditions Optional SQL 'where' fragment.
      # @param  [Object, ...]   *binds     Optional bind values that accompany conditions SQL fragment.
      # @param  [Proc]          &block     Optional 'each' iterator block.
      # @return [Swift::Scheme, nil]
      def first conditions = '', *binds, &block
        Swift.db.first(self, conditions, *binds, &block)
      end
    end
  end # Scheme
end # Swift

