$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'minitest/spec'
require 'minitest/unit'
require 'swift'
require 'etc'

class MiniTest::Spec
  def self.supported_by *adapters, &block
    adapter_defaults    = { Swift::DB::Sqlite3 => { db: ':memory:' } }
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
        block.call(adapter)
      end
    end
  end
end

MiniTest::Unit.autorun
