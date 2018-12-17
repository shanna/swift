$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift(File.join(File.dirname(__FILE__), '..', 'test'))

require 'bundler/setup'
require 'etc'
require 'minitest/autorun'

require 'swift'
require 'swift/adapter/mysql'
require 'swift/adapter/postgres'
require 'swift/adapter/sqlite3'
require 'swift/migrations'

ADAPTER_DEFAULTS = {
  Swift::Adapter::Sqlite3  => {db: ':memory:'},
  Swift::Adapter::Postgres => {host: 'postgres', port: 5432, db: 'swift_test', user: 'swift', password: 'swift'},
  Swift::Adapter::Mysql    => {host: 'mysqll', port: 3306, db: 'swift_test', user: 'swift', password: 'swift'},
}.freeze

class MiniTest::Spec
  def self.supported_by *adapters, &block
    adapters.each do |adapter|
      RETRIES.times do
        begin
          Swift.setup :default, adapter, ADAPTER_DEFAULTS[adapter]
        rescue => error
          warn "Unable to setup 'swift_test' db for #{adapter}, #{error.message}. Skipping..."
          next
        end

        describe("Adapter #{adapter.name}") do
          before do
            Swift.setup :default, adapter, ADAPTER_DEFAULTS[adapter]
          end
          after do
            Swift.db.close
          end
          block.call(adapter)
        end
        break
      end
    end
  end
end

class Minitest::Test
  def self.adapter_defaults *args
    Spec.adapter_defaults *args
  end
end
