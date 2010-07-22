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

