require 'forwardable'

module Swift
  class Result
    include Enumerable
    extend  Forwardable

    def_delegators :@result, :select_rows, :affected_rows, :fields, :types, :insert_id

    def initialize scheme, result
      @scheme = scheme
      @result = result
    end

    def each
      @result.each do |tuple|
        yield @scheme.allocate.tap {|s| s.tuple = tuple}
      end
    end
  end # Result
end # Swift
