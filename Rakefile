require 'rake'
require 'date'

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'yard'
YARD::Rake::YardocTask.new do |yard|
  yard.files = Dir["lib/**/*.rb"].reject{|file| %r{eventmachine|synchrony}.match(file)}
end

require_relative 'lib/swift/version'
$gemspec = Gem::Specification.new do |s|
  s.name                  = 'swift'
  s.version               = Swift::VERSION
  s.authors               = ['Shane Hanna', %q{Bharanee 'Barney' Rathna}]
  s.date                  = Date.today
  s.description           = 'A rational rudimentary database abstraction.'
  s.summary               = 'A rational rudimentary database abstraction.'
  s.email                 = ['shane.hanna@gmail.com', 'deepfryed@gmail.com']
  s.licenses              = %w{MIT}
  s.homepage              = 'http://github.com/shanna/swift'
  s.require_paths         = %w{lib}
  s.required_ruby_version = '>= 1.9.2'

  s.files            = `git ls-files`.split("\n").reject{|f| f =~ %r{\.gitignore|examples|benchmarks|memory|gems/.*|Gemfile}}
  s.test_files       = `git ls-files -- test/*`.split("\n")
  s.extra_rdoc_files = %w{LICENSE README.md}

  # testing
  s.add_development_dependency 'minitest', '>= 1.7.0'

  # swift drivers
  s.add_development_dependency 'swift-db-sqlite3'
  s.add_development_dependency 'swift-db-postgres'
  s.add_development_dependency 'swift-db-mysql'

  # async
  s.add_development_dependency 'eventmachine'
  s.add_development_dependency 'em-synchrony'

  # rake
  s.add_development_dependency 'rake'
  s.add_development_dependency 'yard'
end

desc 'Generate gemspec'
task :gemspec do
  File.open('%s.gemspec' % $gemspec.name, 'w') {|fh| fh.write($gemspec.to_ruby)}
end
