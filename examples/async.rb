#!/usr/bin/ruby

require 'etc'
require 'pp'
require_relative '../lib/swift'
require_relative '../lib/swift/pool'

Swift.setup :pg, db: "dbicpp", user: Etc.getlogin, driver: "postgresql"

Swift.pool(5, :pg) do
  execute("select pg_sleep(0.5), * from users where id = 3") {|r| pp r.fetchrow }
  execute("select pg_sleep(0.3), * from users where id = 2") {|r| pp r.fetchrow }
  execute("select pg_sleep(0.1), * from users where id = 1") {|r| pp r.fetchrow }
end
