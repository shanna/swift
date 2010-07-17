module Swift
  class Properties
    include Enumerable

    def initialize *properties
      @properties = {}
      push *properties
    end

    def new_tuple
      Hash[insertable.map{|field| [field, @properties[field].default]}]
    end

    def push *properties
      @properties.update Hash[properties.map{|property| [property.field, property]}]
    end

    def insertable
      @_insertalbe ||= all - [serial]
    end

    def updatable
      @_updatable ||= all - (keys | [serial])
    end

    def all
      @_all ||= @properties.keys
    end

    def serial
      @_serial ||= find(&:serial?).field
    end

    def serial?
      !!serial
    end

    def keys
      @_keys ||= select(&:key?).map(&:field)
    end

    def each &block
      @properties.values.each{|v| yield v}
    end
  end # Properties
end # Swift

