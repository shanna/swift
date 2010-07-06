#!/usr/bin/env ruby
require_relative '../lib/swift'
require 'pp'
require 'delegate'

class DebugAdapter < DelegateClass(Swift::Adapter)
  [:find, :create, :transaction].each do |sub|
    define_method(sub) do |*args, &block|
      pp [sub, args, (block_given? ? '&block' : nil)].compact
      super *args, &block
    end
  end
end

class MemoryAdapter < Swift::Adapter
  def find model, *args
    # TODO:
  end

  def create *resources
    resources.flatten.each do |resource|
      # Or something.
      # @objects["#{resource.model}:#{resource.keys}"] = resource
    end
  end
end # Memory

class User < Swift::Model.meta do
    property :name, String
    property :age,  Integer
  end
end # User

Swift.setup :default, DebugAdapter.new(MemoryAdapter.new)

Swift.db do
  create User.new(name: 'fred')
  find User, name: 'fred'
end
