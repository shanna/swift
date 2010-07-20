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
      @_insertable ||= all - [serial]
    end

    def updatable
      @_updatable ||= all - (keys | [serial])
    end

    def all
      @_all ||= @properties.keys
    end

    def serial
      # TODO maybe rescue slows it a bit and we should be doing
      #      select(&:serial?).map(:&field).first instead ?
      @_serial ||= find(&:serial?).field rescue nil
    end

    def serial?
      !!serial
    end

    def keys
      @_keys ||= select(&:key?).map(&:field)
    end

    def indexes
      @_indexes ||= select(&:index?).map(&:index).inject({}) {|i, (n, f)| (i[n] ||= []) << f; i }
    end

    def each &block
      @properties.values.each{|v| yield v}
    end
  end # Properties
end # Swift

