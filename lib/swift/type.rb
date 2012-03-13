module Swift
  module Type
    class BigDecimal < Attribute; end
    class Boolean    < Attribute; end
    class Date       < Attribute; end
    class DateTime   < Attribute; end
    class Float      < Attribute; end
    class Integer    < Attribute; end
    class IO         < Attribute; end
    class String     < Attribute; end

    # deprecated
    class Time < Attribute
      def initialize *args
        warn "Swift::Type::Time is deprecated. Use Swift::Type::DateTime instead"
        super
      end
    end
  end # Type
end # Swift
