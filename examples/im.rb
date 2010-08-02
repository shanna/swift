#!/usr/bin/env ruby
require_relative '../lib/swift'
require_relative '../lib/swift/identity_map'
require 'pp'

im = Swift::IdentityMap.new
10.times do |t|
  im.set("example#{t}", t.to_s)
  pp im.get("example#{t}")
end

GC.start; GC.start

pp im.get('example') #=> nil

