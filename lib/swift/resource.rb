module Swift
  class Resource
    def initialize attributes = {}
      attributes.each{|k, v| send(:"#{k}=", v)}
    end
    alias_method :model, :class

    def tuple
      @tuple ||= model.properties.new_tuple
    end

    def update attributes = {}
      attributes.each{|k, v| send(:"#{k}=", v)}
      Swift.db.update(model, self)
    end

    #--
    # TODO: Adapter should be the only place with SQL. Add an Adapter#destory method.
    # This will pay off when we add mongo, sphinx etc.
    def destroy
      where = model.properties.keys.map{|key| "#{key} = ?"}.join(' and ')
      Swift.db.execute("delete from #{model.store} where #{where}", *tuple.values_at(*model.properties.keys))
    end

    class << self
      attr_writer :store

      def inherited klass
        klass.store = store if store
        klass.properties.push(*properties) if properties
        Swift.resources.push(klass) if klass.name
      end

      def load tuple
        resource = allocate
        resource.tuple.update(tuple)
        resource
      end

      def schema &definition
        Dsl.new(self, &definition).resource
      end

      def properties
        @properties ||= Properties.new
      end

      def store
        @store ||= (name ? name.to_s.downcase.gsub(/[^:]+::/, '') : nil)
      end

      def create attributes = {}
        Swift.db.create(self, attributes)
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

    class Dsl
      attr_reader :resource

      def self.const_missing klass
        Property.const_get(klass)
      end

      def initialize model, &definition
        @resource = Class.new(model)
        instance_eval(&definition)
      end

      def property name, type, options = {}
        @resource.properties.push(property = property_type(type).new(@resource, name, options))
        (class << @resource; self end).send(:define_method, name, lambda{ property})
     end

      def store name
        @resource.store = name
      end

      protected
        def property_type klass
          klass < Property ? klass : Property.const_get(:"#{klass}")
        end
    end # Dsl
  end # Resource
end # Swift

