module Swift
  class Property
    attr_accessor :name, :field, :type, :key
    alias_method :key?, :key

    def initialize name, type, options = {}
      @name, @type, @field, @key = name, type, options.fetch(:field, name), options.fetch(:key, false)
    end
  end # Property
end # Swift
