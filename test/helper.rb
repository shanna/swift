$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'minitest/spec'
require 'minitest/unit'
require 'swift'

class MiniTest::Unit::TestCase
end

class MiniTest::Spec
  def self.supported_by *adapters, &block
    adapters.each do |adapter|
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

# All tests run in this timezone.
ENV['TZ'] = ":Australia/Melbourne"
MiniTest::Unit.autorun
