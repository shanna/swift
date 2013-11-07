Gem::Specification.new do |s|
  s.name                  = 'swift'
  s.version               = '1.2.0'
  s.authors               = ['Shane Hanna', %q{Bharanee 'Barney' Rathna}]
  s.date                  = '2013-03-10'
  s.description           = 'A rational rudimentary database abstraction.'
  s.summary               = 'A rational rudimentary database abstraction.'
  s.email                 = ['shane.hanna@gmail.com', 'deepfryed@gmail.com']
  s.files                 = []
  s.licenses              = %w{MIT}
  s.homepage              = 'http://github.com/shanna/swift'
  s.require_paths         = %w{lib}
  s.required_ruby_version = '>= 1.9.2'

  s.files            = `git ls-files`.split("\n").reject{|f| f =~ %r{\.gitignore|examples|benchmarks|memory|gems/.*|Gemfile}}
  s.test_files       = `git ls-files -- test/*`.split("\n")
  s.extra_rdoc_files = %w{LICENSE README.md}

  # testing
  s.add_development_dependency 'minitest', '>= 1.7.0'

  # dm
  s.add_development_dependency 'dm-core'
  s.add_development_dependency 'dm-do-adapter'
  s.add_development_dependency 'dm-postgres-adapter'
  s.add_development_dependency 'dm-mysql-adapter'
  s.add_development_dependency 'dm-sqlite-adapter'
  s.add_development_dependency 'dm-migrations'

  # dm drivers
  s.add_development_dependency 'data_objects'
  s.add_development_dependency 'do_postgres'
  s.add_development_dependency 'do_mysql'
  s.add_development_dependency 'do_sqlite3'

  # ar
  s.add_development_dependency 'activerecord'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'mysql2'
  s.add_development_dependency 'i18n'
  s.add_development_dependency 'builder'
  s.add_development_dependency 'sqlite3-ruby'

  # sequel
  s.add_development_dependency 'sequel'
  s.add_development_dependency 'sequel_pg'
  s.add_development_dependency 'pg_typecast'
  s.add_development_dependency 'home_run'

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

