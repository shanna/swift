require_relative 'helper'

describe 'Adapter' do
  supported_by Swift::DB::Postgres, Swift::DB::Mysql, Swift::DB::DB2 do
    describe 'character encoding' do
      before do
        Swift.db do |db|
          db.execute %q{drop table users} rescue nil
          db.execute %q{create table users(name varchar(128))}

          # Mysql on debian at least doesn't default to utf8.
          if db.kind_of? Swift::DB::Mysql
            db.execute %q{alter table users default character set utf8}
            db.execute %q{alter table users change name name text charset utf8}
          end
        end
      end

      it 'should store and retrieve utf8 characters' do
        Swift.db do |db|
          name = "King of \u2665s"
          db.prepare("insert into users (name) values(?)").execute(name)
          value = db.prepare("select * from users limit 1").execute.first[:name]
          assert_equal Encoding::UTF_8, value.encoding
          assert_equal name, value
        end
      end

      it 'should store and retrieve non ascii' do
        Swift.db do |db|
          name = "\xA1\xB8".force_encoding("euc-jp")
          db.prepare("insert into users (name) values(?)").execute(name)
          value = db.prepare("select * from users limit 1").execute.first[:name]
          assert_equal Encoding::UTF_8, value.encoding
          assert_equal name.encode("utf-8"), value
        end
      end
    end
  end
end
