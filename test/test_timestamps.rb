require_relative 'helper'
require 'date'

describe 'Adapter' do
  supported_by Swift::DB::Postgres do
    describe 'time parsing and time zones' do

      before do
        @db = Swift.db.class.new Swift.db.options.merge(timezone: 'Asia/Kabul')
      end

      it 'should parse timestamps and do conversion accordingly' do
        time  = DateTime.parse('2010-01-01 15:00:00+04:30')
        assert_timestamp_like time, fetch_timestamp_at(time), 'parses correctly'
      end

      it 'should parse correctly when DST is on' do
        time  = DateTime.parse('2010-10-02 20:31:00+04:30')
        assert_timestamp_like time, fetch_timestamp_at(time), 'DST on'
      end

      it 'should parse correctly when DST is off' do
        time  = DateTime.parse('2010-04-04 20:31:00+04:30')
        assert_timestamp_like time, fetch_timestamp_at(time), 'DST off'
      end

      def fetch_timestamp_at value
        sql = "select '%s'::timestamp with time zone as now" % value.strftime('%F %T%z')
        @db.execute(sql)
        @db.results.first.fetch(:now)
      end

      def assert_timestamp_like expect, given, comment
        match = Regexp.new expect.to_time.strftime('%F %T')
        assert_kind_of DateTime, given
        assert_match match, given.strftime('%F %T'), comment
      end
    end
  end
end
