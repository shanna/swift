module Swift

  # An attribute (column) definition.
  #--
  # NOTE: Default method is defined in the extension.
  class Attribute
    attr_reader :name, :field, :key, :serial

    # @example
    #   user = Class.new(Swift::Record)
    #   Swift::Attribute.new(user, :name, Swift::Type::String)
    #
    # @param [Swift::Record] record
    # @param [Symbol]        name
    # @param [Hash]          options
    # @option options [Object, Proc]          :default
    # @option options [Symbol]                :field
    # @option options [TrueClass, FalseClass] :key
    # @option options [TrueClass, FalseClass] :serial
    #
    # @see Swift::Record
    # @see Swift::Type
    def initialize record, name, options = {}
      @name    = name
      @default = options.fetch(:default, nil)
      @field   = options.fetch(:field,   name).to_sym
      @key     = options.fetch(:key,     false)
      @serial  = options.fetch(:serial,  false)
      define_record_methods(record)
    end

    def default
      case @default
        when Numeric, Symbol, true, false, nil
          @default
        when Proc
          @default.call
        else
          @default.dup
      end
    end

    # The attributes field.
    #
    # @return [String]
    def to_s
      field.to_s
    end

    # Evals attribute accessors for this attribute into the record.
    def define_record_methods record
      record.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name};        tuple.fetch(:#{field}, nil)   end
        def #{name}= value; tuple.store(:#{field}, value) end
      RUBY
    end
  end # Attribute
end # Swift
