module Swift

  # An attribute (column) definition.
  #--
  # NOTE: Default method is defined in the extension.
  class Attribute
    attr_reader :name, :field, :key, :serial

    # @example
    #   user = Class.new(Swift::Scheme)
    #   Swift::Attribute.new(user, :name, Swift::Type::String)
    #
    # @param [Swift::Scheme] scheme
    # @param [Symbol]        name
    # @param [Hash]          options
    # @option options [Object, Proc]          :default
    # @option options [Symbol]                :field
    # @option options [TrueClass, FalseClass] :key
    # @option options [TrueClass, FalseClass] :serial
    #
    # @see Swift::Scheme
    # @see Swift::Type
    def initialize scheme, name, options = {}
      @name    = name
      @default = options.fetch(:default, nil)
      @field   = options.fetch(:field,   name)
      @key     = options.fetch(:key,     false)
      @serial  = options.fetch(:serial,  false)
      define_scheme_methods(scheme)
    end

    # Evals attribute accessors for this attribute into the scheme.
    def define_scheme_methods scheme
      scheme.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name};        tuple.fetch(:#{field}, nil)   end
        def #{name}= value; tuple.store(:#{field}, value) end
      RUBY
    end
  end # Attribute
end # Swift
