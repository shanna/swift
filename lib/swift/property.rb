module Swift
  class Property
    attr_accessor :name, :field, :key, :default
    attr_reader :set, :max, :min, :length, :precision, :scale
    alias_method :key?, :key

    def initialize model, name, options = {}
      @name      = name
      @field     = options.fetch(:field, name)
      @key       = options.fetch(:key, false)
      @default   = options.fetch(:default, nil)
      @index     = options.fetch(:index, nil)

      # the following are only used for migrations
      @set       = options.fetch(:set, [])
      @min       = options.fetch(:min, nil)
      @max       = options.fetch(:max, nil)
      @precision = options.fetch(:precision, 16)
      @scale     = options.fetch(:scale, 8)
      @length    = options.fetch(:length, 255)
      define_model_methods(model)
    end

    def index
      [ @index == true ? @field : @index, @field ]
    end

    def index?
      !!@index
    end

    def default
      @default.respond_to?(:call) ? @default.call : (@default.nil? ? nil : @default.dup)
    end

    def define_model_methods model
      model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name}; tuple.fetch(:#{field}) end
        def #{name}=(value); tuple.store(:#{field}, value) end
      RUBY
    end

    # TODO: Do something more interesting with types.
    class Serial < Property
    end

    class String < Property
    end

    class Integer < Property
    end

    class Float < Property
    end

    class Double < Property
    end

    class Numeric < Property
    end

    # TODO: Barf in mutator if someone tries to set a value not in the set option.
    class Enum < Property
    end

    class Time < Property
    end

    class Boolean < Property
    end
  end # Property
end # Swift
