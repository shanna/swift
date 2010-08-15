# Extension.
require_relative '../ext/swift'
require_relative 'swift/adapter'
require_relative 'swift/attribute'
require_relative 'swift/db'
require_relative 'swift/header'
require_relative 'swift/scheme'
require_relative 'swift/type'

module Swift
  class << self
    def setup name, type, options = {}
      unless type.kind_of?(Class) && type < Swift::Adapter
        raise TypeError, "Expected +type+ Swift::Adapter subclass but got #{type.inspect}"
      end
      (@repositories ||= {})[name] = type.new(options)
    end

    def db name = nil, &block
      # I pilfered the logic from DM but I don't really understand what is/isn't thread safe.
      scopes     = (Thread.current[:swift_db] ||= [])
      repository = if name || scopes.empty?
        @repositories[name || :default] or raise "Unknown db '#{name || :default}', did you forget to #setup?"
      else
        scopes.last
      end

      if block_given?
        begin
          scopes.push(repository)
          block.call(repository)
        ensure
          scopes.pop
        end
      end
      repository
    end

    def schema
      @schema ||= []
    end
  end
end # Swift
