require 'swift/result'

module Swift
  class Statement
    def initialize record, command
      @record    = record
      @statement = Swift.db.prepare(command)
    end

    def execute *bind, &block
      Result.new(@record, @statement.execute(*bind), &block)
    end
  end # Statement
end # Swift
