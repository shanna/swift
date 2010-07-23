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
          repository.instance_eval(&block)
        ensure
          scopes.pop
        end
      end
      repository
    end

    def resources
      @resources ||= []
    end

    def migrate!
      resources.each(&:migrate!)
    end

    def trace flag
      Swift::DBI.trace flag
    end

    def init path
      Swift::DBI.init path
    end
  end
end # Swift

