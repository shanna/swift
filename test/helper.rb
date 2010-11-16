$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'minitest/spec'
require 'minitest/unit'
require 'swift'
require 'etc'

class MiniTest::Spec
  def self.supported_by *adapters, &block
    connection_defaults = { db: 'swift_test', user: Etc.getlogin, host: '127.0.0.1' }
    adapters.each do |adapter|
      begin
        Swift.setup :default, adapter, connection_defaults
      rescue => error
        warn "Unable to setup 'swift_test' db for #{adapter}, #{error.message}. Skipping..."
        next
      end

      describe("Adapter #{adapter.name}") do
        before do
          Swift.setup :default, adapter, connection_defaults
        end
        block.call(adapter)
      end
    end
  end
end

MiniTest::Unit.autorun
