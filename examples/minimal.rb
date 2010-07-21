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

pp User.properties

Swift.setup user: Etc.getlogin, driver: 'postgresql', db: 'swift'
Swift.trace true

Swift.db do
  execute(%q{drop table if exists users})
  execute(%q{drop type if exists users_mood_type})
  execute(%q{create type users_mood_type as enum('happy', 'sad')}) # A full range of emotions :P
  execute(%q{create table users(id serial, name text, email text, mood users_mood_type)})

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

