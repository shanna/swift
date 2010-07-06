#!/usr/bin/env ruby
require_relative '../lib/swift'
require 'pp'

# TODO:
class Memory < Swift::Adapter
  def find *args
    pp args
  end
end # Memory

class User < Swift::Model.meta do
    property :name, String
    property :age,  Integer
  end
end # User

Swift.setup :default, Memory.new

Swift.db do
  find(User, name: 'fred')
end
