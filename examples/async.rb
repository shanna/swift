#!/usr/bin/ruby

require 'etc'
require 'pp'
require_relative '../lib/swift'
require_relative '../lib/swift/pool'

Swift.setup :pg, db: "dbicpp", user: Etc.getlogin, driver: "postgresql"

Swift.pool(5, :pg) do
  (1..10).each do |n|
    pause = (10-n)/10.0
    execute("select pg_sleep(#{pause}), * from users where id = 2") {|r| pp r.fetchrow }
  end
end
