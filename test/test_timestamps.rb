require_relative 'helper'
require 'date'

describe 'Adapter' do
  supported_by Swift::DB::Postgres, Swift::DB::Mysql do
    describe 'time parsing and time zones' do

      before do
        @db = Swift.db.class.new Swift.db.options.merge(timezone: 'Asia/Kabul')
      end

      it 'should parse timestamps and do conversion accordingly' do
        time  = DateTime.parse('2010-01-01 15:00:00+04:30')
        raw   = time.strftime('%F %H:%M:%S')
        assert_timestamp_like time, fetch_timestamp_at(raw), 'parses correctly'
      end

      it 'should handle DST' do
        time  = DateTime.parse('2010-10-02 20:31:00+04:30')
        raw   = time.strftime('%F %H:%M:%S')
        assert_timestamp_like time, fetch_timestamp_at(raw), 'DST conversion'
      end

      def fetch_timestamp_at value
        sql = case @db
          when Swift::DB::Postgres then "select '%s'::timestamp as now" % value
          when Swift::DB::Mysql    then "select timestamp('%s') as now" % value
        end
        @db.execute(sql)
        @db.results.first.fetch(:now)
      end

      def assert_timestamp_like expect, given, comment
        match = Regexp.new expect.to_time.strftime("%F %H:%M")
        assert_kind_of Time, given
        assert_match match, given.to_s, comment
      end
    end
  end
end
