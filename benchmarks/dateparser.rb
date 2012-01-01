#!/usr/bin/env ruby

require 'swift'
require 'benchmark'

values = DATA.read.split(/\n+/) * 2000


# DateTime#strptime will be 3x faster than DateTime#parse - but cannot handle second fractions.
Benchmark.bm(30) do |bm|
  bm.report("datetime - native") { 10.times { values.each(&DateTime.method(:parse)) }}
  bm.report("datetime - swift")  { 10.times { values.each(&Swift::DateTimeParser.method(:parse)) }}
end

__END__
2011-12-27 08:45:33.012 +1100
2011-12-27 09:18:00.345 +1100
2011-12-27 09:18:34.678 +1100
2011-12-27 09:35:03.901 +1100
2011-12-27 10:50:08.234 +1100
