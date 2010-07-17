# Extension.
require_relative '../ext/swift/dbi'
require_relative 'swift/adapter'
require_relative 'swift/identity_map'
require_relative 'swift/resource'
require_relative 'swift/properties'
require_relative 'swift/property'
require_relative 'swift/statement'

module Swift
  class << self
    def resource &definition
      Resource.schema(&definition)
    end

    def setup name, adapter = {}
      name, adapter = :default, name unless name.kind_of?(Symbol)
      (@repositories ||= {})[name] = adapter.kind_of?(Adapter) ? adapter : Adapter.new(adapter)
    end

    def db name = :default, &block
      repository = @repositories[name] or raise "Unknown db '#{name}', did you forget to #setup?"
      repository.instance_eval(&block) if block_given?
      repository
    end

    def resources
      @@resources ||= []
    end

    def trace flag
      Swift::DBI.trace flag
    end

    def init path
      Swift::DBI.init path
    end
  end
end # Swift

