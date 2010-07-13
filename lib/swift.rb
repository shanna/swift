# Extension.
require_relative '../ext/swift/dbi'
require_relative 'swift/adapter'
require_relative 'swift/identity_map'
require_relative 'swift/model'
require_relative 'swift/property'
require_relative 'swift/statement'

module Swift
  class << self
    def model &definition
      Model.schema(&definition)
    end

    def setup name, adapter = {}
      name, adapter = :default, name unless name.kind_of?(Symbol)
      (@repositories ||= {})[name] = adapter.kind_of?(Adapter) ? adapter : Adapter.new(adapter)
    end

    def db name = :default, &block
      scope = @repositories[name] or raise "Unknown db '#{name}', did you forget to #setup?"
      scope.instance_eval(&block) if block_given?
      scope
    end

    def trace flag
      Swift::DBI.trace flag
    end
  end
end # Swift

