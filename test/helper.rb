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

    describe = Kernel.method(:describe)
    drivers.each do |driver|
      Kernel.send(:define_method, :describe) do |desc, &block|
        describe.call "#{driver} #{desc}", &block
      end
      begin
        adapter = ::Swift::DB.const_get(driver)
        Swift.setup :default, adapter, db: 'swift_test'
      rescue => error
        warn "Unable to setup 'swift_test' db for #{driver}, #{error.message}. Skipping..."
        next
      end
      block.call(adapter)
    end
    ensure
      Kernel.send(:define_method, :describe) {|name, &block| describe.call(name, &block) }
  end
end

MiniTest::Unit.autorun
