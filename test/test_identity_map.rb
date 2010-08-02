require_relative 'helper'
require 'swift/identity_map'

describe 'IdentityMap' do
  before do
    @im = Swift::IdentityMap.new
  end

  it "must return nil on GC'd object" do
    2.times do
      @im.set('foo', 'foo')
      assert_equal 'foo', @im.get('foo')
    end
    GC.start
    assert_nil @im.get('foo')
  end
end
