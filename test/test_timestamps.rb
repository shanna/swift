require_relative 'helper'
require 'date'

describe 'Adapter' do
  supported_by Swift::DB::Postgres do
    %w(America/Chicago Australia/Melbourne).each do |timezone|
      describe 'time parsing in %s' % timezone do
        before do
          @db = Swift.db
          ENV['TZ'] = ":#{timezone}"
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

        describe 'Adapter timezone' do
          %w(+05:30 -05:30).each do |offset|
            it 'should parse timestamps and do conversion accordingly for offset ' + offset do
              @db = Swift::DB::Postgres.new(@db.options.merge(timezone: offset))
              server = DateTime.parse('2010-01-01 10:00:00')
              local  = DateTime.parse('2010-01-01 10:00:00 ' + offset)
              assert_timestamp_like local, fetch_timestamp_at(server, ''), 'parses correctly'
            end
          end
        end

        def fetch_timestamp_at value, zone='%z'
          sql = if zone.empty?
            "select '%s'::timestamp as now"
          else
            "select '%s'::timestamp with time zone as now"
          end

          sql = sql % value.strftime('%F %T' + zone)
          @db.execute(sql).first.fetch(:now)
        end

        def assert_timestamp_like expect, given, comment
          match = Regexp.new expect.to_time.strftime('%F %T')
          assert_kind_of Time, given
          assert_match match, given.strftime('%F %T'), comment
        end
      end
    end
  end
end
