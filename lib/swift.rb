# Extension.
require_relative '../ext/swift/dbi'
require_relative 'swift/adapter'
require_relative 'swift/attribute'
require_relative 'swift/attributes'
require_relative 'swift/identity_map'
require_relative 'swift/scheme'
require_relative 'swift/statement'
require_relative 'swift/type'

module Swift
  class << self
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

    def schema
      @schema ||= []
    end

    def migrate! name = nil
      db(name){ schema.each(&:migrate!)}
    end

    def trace flag
      Swift::DBI.trace flag
    end

    def init path
      Swift::DBI.init path
    end
  end
end # Swift

