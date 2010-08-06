require_relative 'helper'
require 'date'

describe 'Adapter' do
  supported_by Swift::DB::Postgres, Swift::DB::Mysql do
    describe 'time parsing and time zones' do
      it 'should set timezone' do
        assert Swift.db.timezone(8, 0) # +08:00
      end

      it 'should parse timestamps and do conversion accordingly' do
        assert Swift.db.timezone(8, 30) # +08:30

        time  = DateTime.parse('2010-01-01 15:00:00+08:30')
        match = Regexp.new time.to_time.strftime("%F %H:%M")
        sql   = if Swift.db.kind_of?(Swift::DB::Postgres)
          "select '#{time.strftime('%F %H:%M:%S')}'::timestamp as now"
        else
          "select timestamp('#{time.strftime('%F %H:%M:%S')}') as now"
        end
        Swift.db.execute(sql) do |r|
          assert_match match, r[:now].to_s, "parses time and does zone conversion"
        end
      end
    end
  end
end
