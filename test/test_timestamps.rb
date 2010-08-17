require_relative 'helper'
require 'date'

describe 'Adapter' do
  supported_by Swift::DB::Postgres, Swift::DB::Mysql do
    describe 'time parsing and time zones' do

      def fetch_timestamp_at_zone zone, value
        assert Swift.db.timezone(zone)
        sql = case Swift.db
          when Swift::DB::Postgres then "select '%s'::timestamp as now" % value
          when Swift::DB::Mysql    then "select timestamp('%s') as now" % value
        end
        Swift.db.execute(sql)
        Swift.db.results.first.fetch(:now)
      end

      def assert_timestamp_like expect, given, comment
        match = Regexp.new expect.to_time.strftime("%F %H:%M")
        assert_kind_of Time, given
        assert_match match, given.to_s, comment
      end

      it 'should set timezone' do
        assert Swift.db.timezone('PRC')
      end

      it 'should parse timestamps and do conversion accordingly' do
        time  = DateTime.parse('2010-01-01 15:00:00+04:30')
        raw   = time.strftime('%F %H:%M:%S')
        assert_timestamp_like time, fetch_timestamp_at_zone('Asia/Kabul', raw), 'parses correctly'
      end

      it 'should handle DST' do
        time  = DateTime.parse('2010-10-02 20:31:00+04:30')
        raw   = time.strftime('%F %H:%M:%S')
        assert_timestamp_like time, fetch_timestamp_at_zone('Asia/Kabul', raw), 'DST conversion'
      end
    end
  end
end
