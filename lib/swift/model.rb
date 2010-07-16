module Swift

  #--
  # TODO: Save some keystrokes in the adapter by adding more options to property or defining some new methods.
  # * Fetch only keys as hash by field or by name.
  # * Fetch only 'entries' (naming ideas?) aka not keys as hash by field or name.
  class Model
    alias_method :model, :class

    def initialize attributes = {}
      model.properties.each{|p| send(:"#{p.name}=", attributes.fetch(p.name, p.default))}
    end

    def properties by = :property
      return model.properties if by == :property
      model.properties.inject({}) do |ac, p|
        value          = instance_variable_get("@#{p.name}")
        ac[p.send(by)] = value unless (value.nil? && p.default.nil?)
        ac
      end
    end

    def properties= attributes = {}
      model.names.each{|name| instance_variable_set("@#{name}", attributes[name]) if attributes.key?(name)}
    end

    #--
    # TODO: Add IdentityMap calls.
    # TODO: Get rid of names.zip ... and use a field -> name hash.
    def self.load attributes
      names.zip(attributes.values_at(*fields)).inject(allocate){|o, kv| o.instance_variable_set("@#{kv[0]}", kv[1]); o}
    end

    class << self
      attr_accessor :properties, :resource
      def fields;   @fields ||= properties.map(&:field)    end
      def names;    @names  ||= properties.map(&:name)     end
      def key;      @key    ||= properties.select(&:key?)  end
      def serial;   @serial ||= properties.find(&:serial?) end # TODO: Multiple PG sequences?
      def key?;    !!key    end
      def serial?; !!serial end

      def inherited klass
        Swift.models << klass if klass.name
        klass.resource ||= (resource || klass.to_s.downcase.gsub(/[^:]::/, ''))
        (klass.properties ||= []).push *properties
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
        @model.properties << property = Property.new(name, type, options)
        (class << @model; self end).send(:define_method, name, lambda{ property})
        @model.send(:define_method, :"#{name}", lambda{ instance_variable_get(:"@#{name}")})
        @model.send(:define_method, :"#{name}=", lambda{|value| instance_variable_set(:"@#{name}", value)})
      end

      def resource name
        @model.resource = name
      end
    end # Dsl
  end # Model
end # Swift
