module Swift

  # Adapter.
  #
  # @abstract
  # @see      Swift::DB See Swift::DB for concrete adapters.
  class Adapter
    attr_reader :options

    # Select by id(s).
    #
    # @example Single key.
    #   Swift.db.get(User, id: 12)
    # @example Complex primary key.
    #   Swift.db.get(UserAddress, user_id: 12, address_id: 15)
    #
    # @param  [Swift::Scheme] scheme Concrete scheme subclass to load.
    # @param  [Hash]          keys   Hash of id(s) <tt>{id_name: value}</tt>.
    # @return [Swift::Scheme, nil]
    # @see    Swift::Scheme.get
    #--
    # NOTE: Not significantly shorter than Scheme.db.first(User, 'id = ?', 12)
    def get scheme, keys
      resource = scheme.new(keys)
      prepare_get(scheme).execute(*resource.tuple.values_at(*scheme.header.keys)).first
    end

    # Select one or more.
    #
    # @example All.
    #   Swif.db.all(User)
    # @example All with conditions and binds.
    #   Swift.db.all(User, ':name = ? and :age > ?', 'Apple Arthurton', 32)
    # @example Block form iterator.
    #   Swift.db.all(User, ':age > ?', 32) do |user|
    #     puts user.name
    #   end
    #
    # @param  [Swift::Scheme] scheme     Concrete scheme subclass to load.
    # @param  [String]        conditions Optional SQL 'where' fragment.
    # @param  [Object, ...]   *binds     Optional bind values that accompany conditions SQL fragment.
    # @param  [Proc]          &block     Optional 'each' iterator block.
    # @return [Swift::Result]
    # @see    Swift::Scheme.all
    def all scheme, statement = '', *binds, &block
      prepare_all(scheme, statement).execute(*binds, &block)
    end

    # Select one.
    #
    # @example First.
    #   Swif.db.first(User)
    # @example First with conditions and binds.
    #   Swift.db.first(User, ':name = ? and :age > ?', 'Apple Arthurton', 32)
    # @example Block form iterator.
    #   Swift.db.first(User, ':age > ?', 32) do |user|
    #     puts user.name
    #   end
    #
    # @param  [Swift::Scheme] scheme     Concrete scheme subclass to load.
    # @param  [String]        conditions Optional SQL 'where' fragment.
    # @param  [Object, ...]   *binds     Optional bind values that accompany conditions SQL fragment.
    # @param  [Proc]          &block     Optional 'each' iterator block.
    # @return [Swift::Scheme, nil]
    # @see    Swift::Scheme.first
    def first scheme, statement = '', *binds, &block
      prepare_first(scheme, statement).execute(*binds, &block).first
    end

    # Delete one or more.
    #
    # The SQL condition form of Swift::Adapter.destroy.
    #
    # @example All.
    #   Swift.db.delete(User)
    # @example All with conditions and binds.
    #   Swift.db.delete(User, %Q{
    #     delete from #{User.store}
    #     where #{User.name} = ? and #{User.age} > ?
    #   }, 'Apple Arthurton', 32)
    #
    # @param  [Swift::Scheme] scheme     Concrete scheme subclass
    # @param  [String]        conditions Optional SQL 'where' fragment.
    # @param  [Object, ...]   *binds     Optional bind values that accompany conditions SQL fragment.
    # @return [Swift::Result]
    def delete scheme, statement = '', *binds
      prepare_delete(scheme, statement).execute(*binds)
    end

    # Create one or more.
    #
    # @example Scheme.
    #   user = User.new(name: 'Apply Arthurton', age: 32)
    #   Swift.db.create(User, user)
    #   #=> Swift::Scheme
    # @example Coerce hash to scheme.
    #   Swif.db.create(User, name: 'Apple Arthurton', age: 32)
    #   #=> Swift::Scheme
    # @example Multiple resources.
    #   apple = User.new(name: 'Apple Arthurton', age: 32)
    #   benny = User.new(name: 'Benny Arthurton', age: 30)
    #   Swift.db.create(User, [apple, benny])
    #   #=> Array<Swift::Scheme>
    # @example Coerce multiple resources.
    #   Swift.db.create(User, [{name: 'Apple Arthurton', age: 32}, {name: 'Benny Arthurton', age: 30}])
    #   #=> Array<Swift::Scheme>
    #
    # @param  [Swift::Scheme]                                   scheme    Concrete scheme subclass to load.
    # @param  [Swift::Scheme, Hash, Array<Swift::Scheme, Hash>] resources The resources to be saved.
    # @return [Swift::Scheme, Array<Swift::Scheme>]
    # @note   Hashes will be coerced into a Swift::Scheme resource via Swift::Scheme#new
    # @note   Passing a scalar will result in a scalar.
    # @see    Swift::Scheme.create
    def create scheme, resources
      statement = prepare_create(scheme)
      result    = [resources].flatten.map do |resource|
        resource = scheme.new(resource) unless resource.kind_of?(scheme)
        result   = statement.execute(*resource.tuple.values_at(*scheme.header.insertable))
        resource.tuple[scheme.header.serial] = result.insert_id if scheme.header.serial
        resource
      end
      resources.kind_of?(Array) ? result : result.first
    end

    # Update one or more.
    #
    # @example Scheme.
    #   user      = Swift.db.create(User, name: 'Apply Arthurton', age: 32)
    #   user.name = 'Arthur Appleton'
    #   Swift.db.update(User, user)
    #   #=> Swift::Scheme
    # @example Coerce hash to scheme.
    #   user      = Swift.db.create(User, name: 'Apply Arthurton', age: 32)
    #   user.name = 'Arthur Appleton'
    #   Swif.db.update(User, user.tuple)
    #   #=> Swift::Scheme
    # @example Multiple resources.
    #   apple = Swift.db.create(User, name: 'Apple Arthurton', age: 32)
    #   benny = Swift.db.create(User, name: 'Benny Arthurton', age: 30)
    #   Swift.db.update(User, [apple, benny])
    #   #=> Array<Swift::Scheme>
    # @example Coerce multiple resources.
    #   apple = Swift.db.create(User, name: 'Apple Arthurton', age: 32)
    #   benny = Swift.db.create(User, name: 'Benny Arthurton', age: 30)
    #   Swift.db.update(User, [apple.tuple, benny.tuple])
    #   #=> Array<Swift::Scheme>
    #
    # @param  [Swift::Scheme]                                   scheme    Concrete scheme subclass to load.
    # @param  [Swift::Scheme, Hash, Array<Swift::Scheme, Hash>] resources The resources to be updated.
    # @return [Swift::Scheme, Swift::Result<Swift::Scheme>]
    # @note   Hashes will be coerced into a Swift::Scheme resource via Swift::Scheme#new
    # @note   Passing a scalar will result in a scalar.
    # @see    Swift::Scheme#update
    def update scheme, resources
      statement = prepare_update(scheme)
      result    = [resources].flatten.map do |resource|
        resource = scheme.new(resource) unless resource.kind_of?(scheme)
        keys     = resource.tuple.values_at(*scheme.header.keys)

        # TODO: Name the key field(s) missing.
        raise ArgumentError, "#{scheme} resource has incomplete key: #{resource.inspect}" \
          unless keys.select(&:nil?).empty?

        statement.execute(*resource.tuple.values_at(*scheme.header.updatable), *keys)
        resource
      end
      resources.kind_of?(Array) ? result : result.first
    end

    # Destroy one or more.
    #
    # @example Scheme.
    #   user      = Swift.db.create(User, name: 'Apply Arthurton', age: 32)
    #   user.name = 'Arthur Appleton'
    #   Swift.db.destroy(User, user)
    # @example Coerce hash to scheme.
    #   user      = Swift.db.create(User, name: 'Apply Arthurton', age: 32)
    #   user.name = 'Arthur Appleton'
    #   Swif.db.destroy(User, user.tuple)
    # @example Multiple resources.
    #   apple = Swift.db.create(User, name: 'Apple Arthurton', age: 32)
    #   benny = Swift.db.create(User, name: 'Benny Arthurton', age: 30)
    #   Swift.db.destroy(User, [apple, benny])
    # @example Coerce multiple resources.
    #   apple = Swift.db.create(User, name: 'Apple Arthurton', age: 32)
    #   benny = Swift.db.create(User, name: 'Benny Arthurton', age: 30)
    #   Swift.db.destroy(User, [apple.tuple, benny.tuple])
    #
    # @param  [Swift::Scheme]                                   scheme    Concrete scheme subclass to load.
    # @param  [Swift::Scheme, Hash, Array<Swift::Scheme, Hash>] resources The resources to be destroyed.
    # @return [Swift::Scheme, Array<Swift::Scheme>]
    # @note   Hashes will be coerced into a Swift::Scheme resource via Swift::Scheme#new
    # @note   Passing a scalar will result in a scalar.
    # @see    Swift::Scheme#destroy
    def destroy scheme, resources
      statement = prepare_destroy(scheme)
      result    = [resources].flatten.map do |resource|
        resource = scheme.new(resource) unless resource.kind_of?(scheme)
        keys     = resource.tuple.values_at(*scheme.header.keys)

        # TODO: Name the key field(s) missing.
        raise ArgumentError, "#{scheme} resource has incomplete key: #{resource.inspect}" \
          unless keys.select(&:nil?).empty?

        if result = statement.execute(*keys)
          resource.freeze
        end
        result
      end
      resources.kind_of?(Array) ? result : result.first
    end

    protected
      def prepare_get scheme
        raise NotImplementedError
      end

      def prepare_all scheme, statement = ''
        raise NotImplementedError
      end

      def prepare_first scheme, statement = ''
        raise NotImplementedError
      end

      def prepare_create scheme
        raise NotImplementedError
      end

      def prepare_update scheme
        raise NotImplementedError
      end

      def prepare_destroy scheme
        raise NotImplementedError
      end

  end # Adapter
end # Swift
