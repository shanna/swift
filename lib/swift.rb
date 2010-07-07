# Extension.
require_relative '../ext/swift/dbi'
require 'pp'

module Swift
  class << self
    attr_reader :repositories

    #--
    # TODO: Setup :default with single argument.
    def setup *args
      args.unshift :default if args.first.kind_of?(Adapter)
      @repositories ||= {}
      @repositories[args[0]] = args[1]
    end

    def db name = :default, &block
      pp @repositories
      scope = @repositories[name] or raise "Unknown db '#{name}', did you forget to #setup?"
      scope.dup.instance_eval(&block) if block_given?
      scope
    end
  end

  class Adapter < DBI::Handle
    def self.new options
      # MASSIVE HAX! Barney defining a new in the extension is breaking inheritance. It means allocate and initialize
      # aren't called in subclasses like Adapter so you end up with the wrong object. I think we need to get rid of
      # those new singleton methods and replace them with either initialize rb_define_method(cBlah, "initialize"...)
      # or probably more correctly (I think) an rb_define_alloc_func() for initializing C stuff (if there if you
      # aren't going to set vars in Ruby land.
      adapter = self.allocate
      adapter.send(:initialize)
      adapter
    end
=begin
    def prepare model, query
      # TODO: Bugs Barney, getting a random error Expected type Data but got Swift::Adapter.
      sth = super query
      # TODO: Wrap in delegate class so that when execute is called the resulting iterator knows the correct model to
      # load each row into.
      sth
    end
=end
    #--
    # Tiny sugar for this uber common one.
    def get model, *ids
      keys = model.properties.keys.map{|k| "#{k.field} = ?"}.join(', ')
      # TODO: model.properties.resource
      prepare(model, "select * from #{model.to_s.downcase} where #{keys}").execute(*ids).first
    end

    def create *resources
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

