# -*- encoding: utf-8 -*-
# stub: swift 1.2.1 ruby lib

Gem::Specification.new do |s|
  s.name = "swift"
  s.version = "1.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Shane Hanna", "Bharanee 'Barney' Rathna"]
  s.date = "2014-09-12"
  s.description = "A rational rudimentary database abstraction."
  s.email = ["shane.hanna@gmail.com", "deepfryed@gmail.com"]
  s.extra_rdoc_files = ["LICENSE", "README.md"]
  s.files = ["API.rdoc", "LICENSE", "README.md", "Rakefile", "lib/swift.rb", "lib/swift/version.rb", "lib/swift/adapter.rb", "lib/swift/adapter/em/mysql.rb", "lib/swift/adapter/em/postgres.rb", "lib/swift/adapter/eventmachine.rb", "lib/swift/adapter/mysql.rb", "lib/swift/adapter/postgres.rb", "lib/swift/adapter/sql.rb", "lib/swift/adapter/sqlite3.rb", "lib/swift/adapter/synchrony.rb", "lib/swift/adapter/synchrony/mysql.rb", "lib/swift/adapter/synchrony/postgres.rb", "lib/swift/attribute.rb", "lib/swift/fiber_connection_pool.rb", "lib/swift/header.rb", "lib/swift/identity_map.rb", "lib/swift/migrations.rb", "lib/swift/record.rb", "lib/swift/result.rb", "lib/swift/statement.rb", "lib/swift/type.rb", "lib/swift/validations.rb", "swift.gemspec", "test/helper.rb", "test/house-explode.jpg", "test/test_adapter.rb", "test/test_async.rb", "test/test_datetime_parser.rb", "test/test_encoding.rb", "test/test_error.rb", "test/test_identity_map.rb", "test/test_io.rb", "test/test_record.rb", "test/test_swift.rb", "test/test_synchrony.rb", "test/test_timestamps.rb", "test/test_transactions.rb", "test/test_types.rb", "test/test_validations.rb"]
  s.homepage = "http://github.com/shanna/swift"
  s.licenses = ["MIT"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")
  s.rubygems_version = "2.2.0"
  s.summary = "A rational rudimentary database abstraction."
  s.test_files = ["test/helper.rb", "test/house-explode.jpg", "test/test_adapter.rb", "test/test_async.rb", "test/test_datetime_parser.rb", "test/test_encoding.rb", "test/test_error.rb", "test/test_identity_map.rb", "test/test_io.rb", "test/test_record.rb", "test/test_swift.rb", "test/test_synchrony.rb", "test/test_timestamps.rb", "test/test_transactions.rb", "test/test_types.rb", "test/test_validations.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<minitest>, [">= 1.7.0"])
      s.add_development_dependency(%q<swift-db-sqlite3>, [">= 0"])
      s.add_development_dependency(%q<swift-db-postgres>, [">= 0"])
      s.add_development_dependency(%q<swift-db-mysql>, [">= 0"])
      s.add_development_dependency(%q<eventmachine>, [">= 0"])
      s.add_development_dependency(%q<em-synchrony>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<yard>, [">= 0"])
    else
      s.add_dependency(%q<minitest>, [">= 1.7.0"])
      s.add_dependency(%q<swift-db-sqlite3>, [">= 0"])
      s.add_dependency(%q<swift-db-postgres>, [">= 0"])
      s.add_dependency(%q<swift-db-mysql>, [">= 0"])
      s.add_dependency(%q<eventmachine>, [">= 0"])
      s.add_dependency(%q<em-synchrony>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<yard>, [">= 0"])
    end
  else
    s.add_dependency(%q<minitest>, [">= 1.7.0"])
    s.add_dependency(%q<swift-db-sqlite3>, [">= 0"])
    s.add_dependency(%q<swift-db-postgres>, [">= 0"])
    s.add_dependency(%q<swift-db-mysql>, [">= 0"])
    s.add_dependency(%q<eventmachine>, [">= 0"])
    s.add_dependency(%q<em-synchrony>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<yard>, [">= 0"])
  end
end
