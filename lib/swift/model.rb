module Swift
  class Model
    alias_method :model, :class

    def initialize attributes = {}
      attributes.each{|k, v| send(:"#{k}=", v)} # TODO: Don't create symbols willy nilly.
    end

    def properties by = :property
      return model.properties if by == :property
      model.properties.values.inject({}) do |ac, p|
       ac[p.send(by)] = instance_variable_get("@#{p.name}") unless instance_variable_get("@#{p.name}").nil?
       ac
      end
    end

    #--
    # TODO: Add IdentityMap calls.
    def self.load attributes
      obj = new
      names.zip(attributes.values_at(*fields)).each{|k, v| obj.instance_variable_set("@#{k}", v)}
      obj
    end

    class << self
      attr_accessor :properties, :resource
      def fields;   @fields ||= properties.values.map(&:field) end
      def names;    @names  ||= properties.keys                end
      def key;      @key    ||= properties.values.find(&:key?) end

      def inherited klass
        klass.resource   ||= (resource || klass.to_s.downcase.gsub(/[^:]::/, ''))
        klass.properties ||= {}
        klass.properties.update(properties || {})
      end

      def schema &definition
        Dsl.new(self, &definition).model
      end
    end

    class Dsl
      attr_reader :model

      def initialize model, &definition
        @model = Class.new(model)
        instance_eval(&definition)
      end

      def property name, type, options = {}
        @model.properties[name] = property = Property.new(name, type, options)
        (class << @model; self end).send(:define_method, name, lambda{ property})
        @model.send(:define_method, :name, lambda{ instance_variable_get(:"@#{name}")})
        @model.send(:define_method, :"#{name}=", lambda{|value| instance_variable_set(:"@#{name}", value)})
      end

      def resource name
        @model.resource = name
      end
    end # Dsl
  end # Model
end # Swift
