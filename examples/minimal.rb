#!/usr/bin/env ruby
require_relative '../lib/swift'
require 'etc'
require 'pp'

class User < Swift.resource do
    store    :users
    property :id,    Serial, key: true
    property :name,  String
    property :email, String
    property :mood,  Enum,   set: %w{happy sad}
  end
end # User

Swift.setup user: Etc.getlogin, db: 'swift', driver: ARGV[0] || 'postgresql'
Swift.trace true

Swift.db do
  # TODO: Automigrate takes care of this in swift-orm.
  execute(%q{drop table if exists users})
  case driver
    when 'postgresql'
      execute %q{drop type if exists users_mood_type}
      execute %q{create type users_mood_type as enum('happy', 'sad')} # A full range of emotions :P
      execute %q{create table users(id serial, name text, email text, mood users_mood_type)}
    when 'mysql'
      execute %q{create table users(id serial, name text, email text, mood enum('happy', 'sad'))}
  end

  puts '-- create --'
  create(User,
    {name: 'Apple Arthurton', email: 'apple@arthurton.local', mood: 'happy'},
    {name: 'Benny Arthurton', email: 'benny@arthurton.local', mood: 'sad'}
  )

  puts '', '-- select --'
  pp users = prepare(User, 'select * from users').execute.to_a

  puts '', '-- update --'
  update(User, *users.map!{|user| user.name = 'Fred Nurk'; user})
  pp prepare(User, 'select * from users').execute.to_a

  puts '', '-- get --'
  pp get(User, id: 1)
end

