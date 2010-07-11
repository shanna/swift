# Extension.
require_relative '../ext/swift/dbi'
require 'delegate'
require 'pp'

module Swift
  class << self
    def model &definition
      Model.schema(&definition)
    end

    def setup name, adapter = {}
      name, adapter = :default, name unless name.kind_of?(Symbol)
      (@repositories ||= {})[name] = adapter.kind_of?(Adapter) ? adapter : Adapter.new(adapter)
    end

    def db name = :default, &block
      scope = @repositories[name] or raise "Unknown db '#{name}', did you forget to #setup?"
      scope.instance_eval(&block) if block_given?
      scope
    end
  end

  # Weak hash set.
  #--
  # TODO: Is 'hash set' the real name for a hash where both the keys and values must be unique?
  class IdentityMap
    def initialize
      @cache, @reverse_cache, @finalize = {}, {}, method(:finalize)
    end

    def get key
      value_id = @cache[key]
      return ObjectSpace._id2ref(value_id) unless value_id.nil?
      nil
    end

    #--
    # TODO: Barf if the value.object_id already exists in the cache.
    def set key, value
      @reverse_cache[value.object_id] = key
      @cache[key]                     = value.object_id
      ObjectSpace.define_finalizer(value, @finalize)
    end

    private
      def finalize value_id
        @cache.delete @reverse_cache.delete value_id
      end
  end # IdentityMap

  class Statement < DBI::Statement
    def initialize adapter, model, query
      @model = model
      super adapter, query
    end

    def each
      super{|att| yield @model.load att}
    end
  end

  class Adapter < DBI::Handle
    def identity_map
      @identity_map ||= IdentityMap.new
    end

    def prepare model, query = nil
      return super(model) unless model.kind_of?(Class) && model < Model
      Statement.new(self, model, query)
    end

    def get model, *ids
      keys = model.keys.map{|k| "#{k.field} = ?"}.join(', ')
      prepare(model, "select * from #{model.resource} where #{keys}").execute(*ids).first
    end

    #--
    # TODO: This is where it gets suck.
    # * Optional model first argument for single prepare multiple execute form.
    # * DB sync, default values, ids?
    def create *resources
      resources.each do |resource|
        attributes = resource.properties :field
        fields     = attributes.keys.join(', ')
        binds      = attributes.values
        supply     = (['?'] * attributes.size).join(', ')
        # TODO: Execute is farked Barney!
        # if execute("insert into #{resource.model.resource} (#{fields}) values (#{supply})", *binds)
        if prepare("insert into #{resource.model.resource} (#{fields}) values (#{supply})").execute(*binds)
        end
      end
    end

    def update *resources
    end

    def transaction name = nil, &block
      super(name){ self.instance_eval(&block)}
    end
  end # Adapter

  class Property
    attr_accessor :name, :field, :type, :key
    alias_method :key?, :key

    def initialize name, type, options = {}
      @name, @type, @field, @key = name, type, options.fetch(:field, name), options.fetch(:key, false)
    end
  end # Property

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
    # TODO: Add IdentityMapp calls.
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
  end # Model

  class Model::Dsl
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
  end # Model::Dsl
end

