require 'minitest/unit'
require 'minitest/spec'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'swift'
require 'swift/pool'

class MiniTest::Unit::TestCase
end

class MiniTest::Spec
  def self.supported_by *adapters, &block
    adapters.each do |adapter|
      # test if adapter can be loaded.
      begin
        Swift.setup :default, adapter, db: 'swift_test'
      rescue => error
        warn "Unable to setup 'swift_test' db for #{adapter}, #{error.message}. Skipping..."
        next
      end
      describe("Adapter #{adapter.name}") do
        before do
          Swift.setup :default, adapter, db: 'swift_test'
        end
        block.call(adapter)
      end
    end
  end
end

MiniTest::Unit.autorun
