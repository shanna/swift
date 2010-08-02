require 'minitest/unit'
require 'minitest/spec'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'swift'

class MiniTest::Unit::TestCase
end

class MiniTest::Spec

  # supported_by :Postgres, :Mysql
  def self.supported_by *drivers, &block
    drivers.each do |driver|
      begin
        adapter = ::Swift::DB.const_get(driver)
        Swift.setup :default, adapter, db: 'swift_test'
      rescue => error
        warn "Unable to setup 'swift_test' db for #{driver}, #{error.message}. Skipping..."
        next
      end
      block.call(adapter)
    end
  end
end

MiniTest::Unit.autorun
