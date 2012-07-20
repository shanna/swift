require 'swift/result'

module Swift
  # Statement.
  #
  # Wrapper for server side prepared statements.
  class Statement
    def initialize record, command
      @record    = record
      @statement = Swift.db.prepare(command)
    end

    # Execute a statement.
    #
    # @example
    #   statement = Swift.db.prepare(User, "select * from users where id > ?")
    #   statement.execute(10)
    #
    # @param  [*Object]         bind    Bind values
    # @return [Swift::Result]
    def execute *bind, &block
      Result.new(@record, @statement.execute(*bind), &block)
    end
  end # Statement
end # Swift
