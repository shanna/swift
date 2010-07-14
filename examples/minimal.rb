#!/usr/bin/env ruby
require_relative '../lib/swift'
require_relative '../lib/swift/sugar'
require_relative '../lib/swift/migrations'
require 'etc'
require 'pp'

require 'delegate'
class DebugAdapter < DelegateClass(Swift::Adapter)
  [:prepare, :execute, :get, :transaction].each do |sub|
    define_method(sub) do |*args, &block|
      pp [sub, args, (block_given? ? '&block' : nil)].compact
      super *args, &block
    end
  end
end

class User < Swift::Model.schema do
    resource :users
    property :id,       Integer, key: true, serial: true
    property :name,     String
    property :email,    String
    property :optional, String, default: 'woot'
  end
end # User

Swift.setup user: Etc.getlogin, driver: 'postgresql', db: 'swift'
Swift.trace true
Swift.auto_migrate!

Swift.db do
  create(User,
    {name: 'Apple Arthurton', email: 'apple@arthurton.local'},
    {name: 'Benny Arthurton', email: 'benny@arthurton.local'}
  )
  # Same as: create(User, User.new(...), User.new(...))

  users = prepare(User, 'select * from users').execute.map do |user|
    user.optional = 'testing'
    user
  end

  update(User, *users)

  pp get(User, 1)
end

User.only(name: 'foo', limit: 1, offset: 2) {|u| pp u }

pp User.all(':name like ? limit 1 offset 1', '%Arthurton').first

user = User.create name: 'James Arthurton', email: 'james@arthurton.local'

pp user
user.update(name: 'Jimmy Arthurton')

pp User.only(name: user.name).first
