module Swift

  # Adapter.
  #
  # @abstract
  # @see      Swift::DB See Swift::DB for concrete adapters.
  # @todo     For the time being all adapters are SQL and DBIC++ centric. It would be super easy to abstract though I
  #           don't know if you would be better off doing it at the Ruby or DBIC++ level (or both).
  #--
  # TODO: Extension methods are undocumented.
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
      relation = scheme.new(keys)
      prepare_get(scheme).execute(*relation.tuple.values_at(*scheme.header.keys)).first
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
    def all scheme, conditions = '', *binds, &block
      where = "where #{exchange_names(scheme, conditions)}" unless conditions.empty?
      prepare(scheme, "select * from #{scheme.store} #{where}").execute(*binds, &block)
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
    def first scheme, conditions = '', *binds, &block
      where = "where #{exchange_names(scheme, conditions)}" unless conditions.empty?
      prepare(scheme, "select * from #{scheme.store} #{where} limit 1").execute(*binds, &block).first
    end

    # Create one or more.
    #
    # @example Scheme.
    #   user = User.new(name: 'Apply Arthurton', age: 32)
    #   Swift.db.create(User, user)
    # @example Coerce hash to scheme.
    #   Swif.db.create(User, name: 'Apple Arthurton', age: 32)
    # @example Multiple relations.
    #   apple = User.new(name: 'Apple Arthurton', age: 32)
    #   benny = User.new(name: 'Benny Arthurton', age: 30)
    #   Swift.db.create(User, apple, benny)
    # @example Coerce multiple relations.
    #   Swift.db.create(User, {name: 'Apple Arthurton', age: 32}, {name: 'Benny Arthurton', age: 30})
    #
    # @param  [Swift::Scheme]       scheme     Concrete scheme subclass to load.
    # @param  [Swift::Scheme, Hash> *relations Scheme or tuple hash. Hashes will be coerced into scheme via Swift::Scheme#new
    # @return [Array<Swift::Scheme>]
    # @see    Swift::Scheme.create
    def create scheme, *relations
      statement = prepare_create(scheme)
      relations.map do |relation|
        relation = scheme.new(relation) unless relation.kind_of?(scheme)
        result   = statement.execute(*relation.tuple.values_at(*scheme.header.insertable))
        relation.tuple[scheme.header.serial] = result.insert_id if scheme.header.serial
        relation
      end
    end

    # Update one or more.
    #
    # @example Scheme.
    #   user      = Swift.db.create(User, name: 'Apply Arthurton', age: 32)
    #   user.name = 'Arthur Appleton'
    #   Swift.db.update(User, user)
    # @example Coerce hash to scheme.
    #   user      = Swift.db.create(User, name: 'Apply Arthurton', age: 32)
    #   user.name = 'Arthur Appleton'
    #   Swif.db.update(User, user.tuple)
    # @example Multiple relations.
    #   apple = Swift.db.create(User, name: 'Apple Arthurton', age: 32)
    #   benny = Swift.db.create(User, name: 'Benny Arthurton', age: 30)
    #   Swift.db.update(User, apple, benny)
    # @example Coerce multiple relations.
    #   apple = Swift.db.create(User, name: 'Apple Arthurton', age: 32)
    #   benny = Swift.db.create(User, name: 'Benny Arthurton', age: 30)
    #   Swift.db.update(User, apple.tuple, benny.tuple)
    #
    # @param  [Swift::Scheme]       scheme     Concrete scheme subclass to load.
    # @param  [Swift::Scheme, Hash> *relations Scheme or tuple hash. Hashes will be coerced into scheme via Swift::Scheme#new
    # @return [Array<Swift::Scheme>]
    # @see    Swift::Scheme#update
    def update scheme, *relations
      statement = prepare_update(scheme)
      relations.map do |relation|
        relation = scheme.new(relation) unless relation.kind_of?(scheme)
        keys     = relation.tuple.values_at(*scheme.header.keys)
        raise ArgumentError, "relation has incomplete key : #{relation.inspect}" unless keys.select(&:nil?).empty?
        statement.execute(*relation.tuple.values_at(*scheme.header.updatable), *keys)
        relation
      end
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
    # @example Multiple relations.
    #   apple = Swift.db.create(User, name: 'Apple Arthurton', age: 32)
    #   benny = Swift.db.create(User, name: 'Benny Arthurton', age: 30)
    #   Swift.db.destroy(User, apple, benny)
    # @example Coerce multiple relations.
    #   apple = Swift.db.create(User, name: 'Apple Arthurton', age: 32)
    #   benny = Swift.db.create(User, name: 'Benny Arthurton', age: 30)
    #   Swift.db.destroy(User, apple.tuple, benny.tuple)
    #
    # @param  [Swift::Scheme]       scheme     Concrete scheme subclass to load.
    # @param  [Swift::Scheme, Hash] *relations Scheme or tuple hash. Hashes will be coerced into scheme via Swift::Scheme#new
    # @see    Swift::Scheme#destroy
    def destroy scheme, *relations
      statement = prepare_destroy(scheme)
      relations.map do |relation|
        relation = scheme.new(relation) unless relation.kind_of?(scheme)
        keys     = relation.tuple.values_at(*scheme.header.keys)
        raise ArgumentError, "relation has incomplete key : #{relation.inspect}" unless keys.select(&:nil?).empty?
        if result = statement.execute(*keys)
          relation.freeze
        end
        result
      end
    end


    # Delete one or more rows
    #
    # @example All.
    #   Swift.db.delete(User)
    # @example All with conditions and binds.
    #   Swift.db.delete(User, ':name = ? and :age > ?', 'Apple Arthurton', 32)
    #
    # @param  [Swift::Scheme] scheme     Concrete scheme subclass
    # @param  [String]        conditions Optional SQL 'where' fragment.
    # @param  [Object, ...]   *binds     Optional bind values that accompany conditions SQL fragment.
    # @return [Swift::Result]
    def delete scheme, conditions = '', *binds
      sql =  "delete from #{scheme.store}"
      sql += " where #{exchange_names(scheme, conditions)}" unless conditions.empty?
      execute(sql, *binds)
    end

    def migrate! scheme
      keys   =  scheme.header.keys
      fields =  scheme.header.map{|p| field_definition(p)}.join(', ')
      fields += ", primary key (#{keys.join(', ')})" unless keys.empty?

      execute("drop table if exists #{scheme.store} cascade")
      execute("create table #{scheme.store} (#{fields})")
    end

    protected
      def exchange_names scheme, query
        query.gsub(/:(\w+)/){ scheme.send($1.to_sym).field }
      end

      def returning?
        raise NotImplementedError
      end

      def prepare_cached scheme, name, &block
        @prepared               ||= Hash.new{|h,k| h[k] = Hash.new} # Autovivification please Matz!
        @prepared[scheme][name] ||= prepare(scheme, yield)
      end

      def prepare_get scheme
        prepare_cached(scheme, :get) do
          where = scheme.header.keys.map{|key| "#{key} = ?"}.join(' and ')
          "select * from #{scheme.store} where #{where} limit 1"
        end
      end

      def prepare_create scheme
        prepare_cached(scheme, :create) do
          values    = (['?'] * scheme.header.insertable.size).join(', ')
          returning = "returning #{scheme.header.serial}" if scheme.header.serial and returning?
          "insert into #{scheme.store} (#{scheme.header.insertable.join(', ')}) values (#{values}) #{returning}"
        end
      end

      def prepare_update scheme
        prepare_cached(scheme, :update) do
          set   = scheme.header.updatable.map{|field| "#{field} = ?"}.join(', ')
          where = scheme.header.keys.map{|key| "#{key} = ?"}.join(' and ')
          "update #{scheme.store} set #{set} where #{where}"
        end
      end

      def prepare_destroy scheme
        prepare_cached(scheme, :destroy) do
          where = scheme.header.keys.map{|key| "#{key} = ?"}.join(' and ')
          "delete from #{scheme.store} where #{where}"
        end
      end

      def field_definition attribute
        "#{attribute.field} " + field_type(attribute)
      end

      def field_type attribute
        case attribute
          when Type::String     then 'text'
          when Type::Integer    then attribute.serial ? 'serial' : 'integer'
          when Type::Float      then 'float'
          when Type::BigDecimal then 'numeric'
          when Type::Time       then 'timestamp'
          when Type::Date       then 'date'
          when Type::Boolean    then 'boolean'
          when Type::IO         then 'blob'
          else 'text'
        end
      end
  end # Adapter
end # Swift
