require 'forwardable'

module Swift
  # Result.
  #
  # Wrapper for command result. It lazily instantiates a new Swift::Record instance for each result row.
  class Result
    include Enumerable
    extend  Forwardable

    def_delegators :@result, :selected_rows, :affected_rows, :fields, :types, :insert_id

    def initialize record, result
      @record = record
      @result = result
    end

    def each
      @result.each do |tuple|
        yield @record.allocate.tap {|s| s.tuple = tuple}
      end
    end
  end # Result
end # Swift
