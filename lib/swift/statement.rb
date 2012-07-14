require 'swift/result'

module Swift
  class Statement
    def initialize scheme, statement
      @scheme    = scheme
      @statement = Swift.db.prepare(statement)
    end

    def execute *bind, &block
      Result.new(@scheme, @statement.execute(*bind), &block)
    end
  end # Statement
end # Swift
