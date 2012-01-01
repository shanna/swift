require_relative 'helper'

describe 'DateTimeParser' do
  it 'should handle ymd style values' do
    text   = "2011-12-31 09:01:02.80300899 +1100"
    time   = DateTime.parse(text)
    result = Swift::DateTime.parse(text)

    assert_equal time, result
  end
end
