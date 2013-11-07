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

class MiniTest::Spec
  def self.supported_by *adapters, &block
    adapter_defaults    = { Swift::Adapter::Sqlite3 => { db: ':memory:' } }
    connection_defaults = { db: 'swift_test', user: Etc.getlogin, host: '127.0.0.1' }
    adapters.each do |adapter|
      begin
        Swift.setup :default, adapter, connection_defaults.merge(adapter_defaults.fetch(adapter, {}))
      rescue => error
        warn "Unable to setup 'swift_test' db for #{adapter}, #{error.message}. Skipping..."
        next
      end

      describe("Adapter #{adapter.name}") do
        before do
          Swift.setup :default, adapter, connection_defaults.merge(adapter_defaults.fetch(adapter, {}))
        end
        after do
          Swift.db.close
        end
        block.call(adapter)
      end
    end
  end
end
