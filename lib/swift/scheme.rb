module Swift
  class Scheme
    alias_method :scheme, :class

    def initialize options = {}
      options.each{|k, v| send(:"#{k}=", v)}
    end

    def tuple
      @tuple ||= scheme.attributes.new_tuple
    end

    def update options = {}
      options.each{|k, v| send(:"#{k}=", v)}
      Swift.db.update(scheme, self)
    end

    #--
    # TODO: Adapter should be the only place with SQL. Add an Adapter#destory method.
    # This will pay off when we add mongo, sphinx etc.
    def destroy
      where = scheme.attributes.keys.map{|key| "#{key} = ?"}.join(' and ')
      Swift.db.execute("delete from #{scheme.store} where #{where}", *tuple.values_at(*scheme.attributes.keys))
    end

    class << self
      def inherited klass
        klass.store(store)                 if store
        klass.attributes.push(*attributes) if attributes
        Swift.schema.push(klass)           if klass.name
      end

      def load tuple
        im = [self, *tuple.values_at(*attributes.keys)]
        unless scheme = Swift.db.identity_map.get(im)
          scheme = allocate
          scheme.tuple.update(tuple)
          Swift.db.identity_map.set(im, scheme)
        end
        scheme
      end

      def attributes
        @attributes ||= Attributes.new
      end

      def attribute name, type, options = {}
        attributes.push(attribute = type.new(self, name, options))
        (class << self; self end).send(:define_method, name, lambda{ attribute })
      end

      def store name = nil
        name ? @store = name : @store
      end

      def migration &migration
        (class << self; self end).send(:define_method, :migrate!, lambda{ Swift.db.instance_eval(&migration) })
      end

      def migrate!
        Swift.db.migrate!(self)
      end

      def create options = {}
        Swift.db.create(self, options)
      end

      #--
      # TODO: Adapter should be the only place with SQL. Add an Adapter#all method.
      # This will pay off when we add mongo, sphinx etc.
      def all where = '', *binds, &block
        where = "where #{exchange_names(where)}" unless where.empty?
        Swift.db.prepare(self, "select * from #{store} #{where}").execute(*binds, &block)
      end

      def first where = '', *binds, &block
        all(where, *binds, &block).first
      end

      def get keys
        Swift.db.get(self, keys)
      end

      protected
        def exchange_names sql
          sql.gsub(/:(\w+)/){ send($1.to_sym).field}
        end
    end
  end # Scheme
end # Swift

