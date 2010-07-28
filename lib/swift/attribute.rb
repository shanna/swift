module Swift
  class Attribute
    attr_reader :name, :field, :key, :serial

    def initialize scheme, name, options = {}
      @name      = name
      @default   = options.fetch(:default, nil)
      @field     = options.fetch(:field,   name)
      @key       = options.fetch(:key,     false)
      @serial    = options.fetch(:serial,  false)
      define_scheme_methods(scheme)
    end

    def default
      @default.respond_to?(:call) ? @default.call : (@default.nil? ? nil : @default.dup)
    end

    def define_scheme_methods scheme
      scheme.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name};        tuple.fetch(:#{field})        end
        def #{name}= value; tuple.store(:#{field}, value) end
      RUBY
    end
  end # Attribute
end # Swift
