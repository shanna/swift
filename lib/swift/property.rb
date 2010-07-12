module Swift
  class Property
    attr_accessor :name, :field, :type, :key, :serial, :default
    alias_method :key?, :key
    alias_method :serial?, :serial

    def initialize name, type, options = {}
      @name    = name
      @type    = type
      @field   = options.fetch(:field, name)
      @key     = options.fetch(:key, false)
      @serial  = options.fetch(:serial, false)
      @default = options.fetch(:default, nil)
    end

    def default
      @default.respond_to?(:call) ? @default.call : (@default.nil? ? nil : @default.dup)
    end
  end # Property
end # Swift
