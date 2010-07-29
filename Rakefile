require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name        = 'swift'
    gem.summary     = %q{A rational rudimentary database abstraction.}
    gem.description = %q{A rational rudimentary database abstraction.}
    gem.email       = %w{shane.hanna@gmail.com deepfryed@gmail.com}
    gem.homepage    = 'http://github.com/shanna/swift'
    gem.authors     = ["Shane Hanna", "Bharanee 'Barney' Rathna"]
    gem.extensions = FileList['ext/extconf.rb']
    gem.files.reject!{|f| f =~ %r{\.gitignore|examples|benchmarks/.*}}
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :test    => :check_dependencies
task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "swift #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
