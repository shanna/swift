#!/usr/bin/ruby

require 'optparse'
require 'benchmark'

ENV['TZ'] = ":Australia/Melbourne"

module Benchmark
  class Tms
    attr_accessor :label, :rss, :stime, :utime, :real
    def output
      "%-16s\t%8.6f\t%8.6f\t%8.6f\t%8.6f\t%.2fm" % [ label, stime, utime, stime+utime, real, rss/1024.0 ]
    end
  end
  def self.run label, &block
    rss1 = `ps -o "rss=" -p #{$$}`.strip.to_i
    tms = measure &block
    rss2 = `ps -o "rss=" -p #{$$}`.strip.to_i
    tms.label  = label
    tms.rss = rss2-rss1
    tms
  end
end

args = { driver: 'postgresql', rows: 500, runs: 5, tests: [], script: [], verbose: true }

OptionParser.new do |opts|
  opts.on('-d', '--driver name') do |name|
    args[:driver] = name
  end
  opts.on('-r', '--rows number') do |n|
    args[:rows] = n.to_i
  end
  opts.on('-n', '--runs number') do |n|
    args[:runs] = n.to_i
  end
  opts.on('-t', '--tests [create, select, update]') do |t|
    args[:tests] << t.to_sym
  end
  opts.on('-v', '--[no-]verbose') do |v|
    args[:verbose] = v
  end
  opts.on('-s', '--script [ ar, dm, swift ]') do |name|
    args[:script] << name
  end
end.parse!

args[:script].uniq!
args[:script] = %w(dm ar swift) if args[:script].empty?
args[:tests]  = %w(create select update).map(&:to_sym) if args[:tests].empty?
args[:rows]   = '*' if args[:tests] == [ :select ]

if args[:verbose]
  puts '', '-- driver: %s rows: %s runs: %d --' % args.values_at(:driver, :rows, :runs)
  puts '', "%-16s\t%-8s\t%-8s\t%-8s\t%-8s\trss" % %w(benchmark sys user total real)
end

require_relative args[:script].shift
Runner.new(args).run {|result| puts result.output }

if !args[:script].empty?
  Kernel.exec(
    "#{$0} %s --no-verbose" %
    args.map {|arg, value| [ value ].flatten.map {|v| "--#{arg} #{v}"}.join(' ') }.join(' ')
  )
end
