module Swift
  class Property
    attr_accessor :name, :field, :key, :default
    alias_method :key?, :key

    def initialize model, name, options = {}
      @name    = name
      @field   = options.fetch(:field, name)
      @key     = options.fetch(:key, false)
      @default = options.fetch(:default, nil)
      @index   = options.fetch(:index, nil)
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

    class Fixnum < Property
    end

    class BigDecimal < Property
    end

    # TODO: Barf in mutator if someone tries to set a value not in the set option.
    class Enum < Property
    end

    class Time < Property
    end
  end # Property
end # Swift
