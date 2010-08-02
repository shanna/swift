#!/usr/bin/env ruby
require_relative '../lib/swift'
require 'etc'
require 'pp'

adapter = ARGV.first =~ /mysql/i ? Swift::DB::Mysql : Swift::DB::Postgres
puts "Using DB: #{adapter}"

im = Swift::IdentityMap.new
10.times do |t|
  im.set("example#{t}", t.to_s)
  pp im.get("example#{t}")
end

GC.start; GC.start

pp im.get('example') #=> nil

