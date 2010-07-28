module Swift
  class Attribute
    attr_accessor :name, :field, :key, :default, :serial
    alias_method :key?, :key
    alias_method :serial?, :serial

    def initialize model, name, options = {}
      @name      = name
      @default   = options.fetch(:default, nil)
      @field     = options.fetch(:field,   name)
      @index     = options.fetch(:index,   nil)
      @key       = options.fetch(:key,     false)
      @serial    = options.fetch(:serial,  false)
      define_model_methods(model)
    end

    def default
      @default.respond_to?(:call) ? @default.call : (@default.nil? ? nil : @default.dup)
    end

    def define_model_methods model
      model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name}; tuple.fetch(:#{field}) end
        def #{name}= value; tuple.store(:#{field}, value) end
      RUBY
    end

    class String < Attribute
    end

    class Integer < Attribute
    end

    class Float < Attribute
    end

    class BigDecimal < Attribute
    end

    class Time < Attribute
    end

    class Boolean < Attribute
    end
  end # Attribute
end # Swift
