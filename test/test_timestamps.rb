require_relative 'helper'
require 'date'

describe 'Adapter' do
  supported_by Swift::DB::Postgres, Swift::DB::Mysql do
    describe 'time parsing and time zones' do
      it 'should set timezone' do
        assert Swift.db.timezone('PRC') # +08:00
      end

      it 'should parse timestamps and do conversion accordingly' do
        time  = DateTime.parse('2010-01-01 15:00:00+04:30')
        match = Regexp.new time.to_time.strftime("%F %H:%M")
        raw   = time.strftime('%F %H:%M:%S')

        assert Swift.db.timezone('Asia/Kabul') # +04:30

        sql = case Swift.db
          when Swift::DB::Postgres then "select '%s'::timestamp as now" % raw
          when Swift::DB::Mysql    then "select timestamp('%s') as now" % raw
        end

        Swift.db.execute(sql) do |r|
          assert_match match, r[:now].to_s, "parses time and does zone conversion"
        end
      end
    end
  end
end
