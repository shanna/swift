$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'minitest/spec'
require 'minitest/unit'
require 'swift'

# db2 database name is limited to 8 characters, gonna use swift instead of swift_test

class MiniTest::Spec
  def self.supported_by *adapters, &block
    adapters.each do |adapter|
      begin
        Swift.setup :default, adapter, db: 'swift'
      rescue => error
        warn "Unable to setup 'swift' db for #{adapter}, #{error.message}. Skipping..."
        next
      end

      describe("Adapter #{adapter.name}") do
        before do
          Swift.setup :default, adapter, db: 'swift'
        end
        block.call(adapter)
      end
    end
  end
end

MiniTest::Unit.autorun
