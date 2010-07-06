module Swift
  class << self
    attr_reader :repositories

    #--
    # TODO: Setup :default with single argument.
    def setup name, adapter
      @repositories ||= {}
      @repositories[name] = adapter
    end

    def db name = :default, &block
      scope = @repositories[name] or raise "Unknown db '#{name}', did you forget to #setup?"
      scope.dup.instance_eval(&block) if block_given?
      scope
    end
  end

  class Adapter # < DBI
    def find model, *args, &block
    end

    def transaction name = nil, &block
      super(name){ self.dup.instance_eval(&block)}
    end
  end # Adapter

  class Property
    attr_accessor :name, :field, :type, :key
    alias_method :key?, :key
    def initialize name, type, options = {}
      @name, @type, @field, @key = name, type, options.fetch(:field, name), options.fetch(:key, false)
    end
  end # Property

  class Properties < Array
    def keys;   find{|p| p.key?} end
    def fields; map(&:field)     end
    def names;  map(&:name)      end
  end # Properties

  class Model
    def initialize(attributes = {})
      attributes.each{|k, v| send("#{k}=", v)}
    end
    alias_method :model, :class

    def self.select *args
      (@repository || Om.repositories[:default]).select(self, *args)
    end

    def self.meta &definition
      Class.new(self){class_eval &definition}
    end

    def self.inherited klass
      klass.properties.push *properties
    end

    #--
    # TODO: Dirty tracking? state.get(property, name); state.set(property, name, value)
    # TODO: State can be used to handle defaults as well.
    def self.property name, type, options = {}
      properties << Property.new(name, type, options)
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name}; @#{name} end
        def #{name}=(value); @#{name} = value end
      RUBY
    end

    def self.properties
      @properties ||= Properties.new
    end

    def properties by = :property
      return model.properties if by == :property
      model.properties.inject({}) do |ac, p|
       ac[p.send(by)] = instance_variable_get("@#{p.name}") unless instance_variable_get("@#{p.name}").nil?
       ac
      end
    end

    def load attributes
      model.properties.names.zip(attrbitues.values_at(*model.properties.fields))
      # attributes.each{|k, v| instance_variable_set("@#{k}", v) if model.properties.names.include?(k)}
    end

    def save
    end
  end
end

