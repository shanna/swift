module Swift
  class Attributes
    include Enumerable

    def initialize *attributes
      @attributes = {}
      push *attributes
    end

    def new_tuple
      Hash[insertable.map{|field| [field, @attributes[field].default]}]
    end

    def push *attributes
      @attributes.update Hash[attributes.map{|attribute| [attribute.field, attribute]}]
    end

    def insertable
      @insertable ||= all - [serial]
    end

    def updatable
      @updatable ||= all - (keys | [serial])
    end

    def all
      @all ||= @attributes.keys
    end

    def serial
      return @serial if defined? @serial
      serial  = find(&:serial)
      @serial = serial ? serial.field : nil
    end

    def keys
      @keys ||= select(&:key).map(&:field)
    end

    def each &block
      @attributes.values.each{|v| yield v}
    end
  end # Attributes
end # Swift

