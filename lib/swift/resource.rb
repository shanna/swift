module Swift
  class Resource
    def initialize attributes = {}
      attributes.each{|k, v| send(:"#{k}=", v)}
    end
    alias_method :model, :class

    def tuple
      @tuple ||= model.properties.new_tuple
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
    end

    class Dsl
      attr_reader :resource

      def initialize model, &definition
        @resource = Class.new(model)
        instance_eval(&definition)
      end

      def property name, type, options = {}
        @resource.properties.push(property = Property.new(name, type, options))
        (class << @resource; self end).send(:define_method, name, lambda{ property})
        @resource.send(:define_method, :"#{name}", lambda{ tuple.fetch(property.field)})
        @resource.send(:define_method, :"#{name}=", lambda{|value| tuple.store(property.field, value)})
      end

      def store name
        @resource.store = name
      end
    end # Dsl
  end # Resource
end # Swift

