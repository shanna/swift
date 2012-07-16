require_relative 'helper'

describe 'Adapter' do
  supported_by Swift::Adapter::Postgres, Swift::Adapter::Mysql, Swift::Adapter::Sqlite3 do
    describe 'Storing binary objects' do
      before do
        user = Class.new(Swift::Record) do
          store :users
          attribute :id,    Swift::Type::Integer, serial: true, key: true
          attribute :name,  Swift::Type::String
          attribute :image, Swift::Type::IO
        end
        Swift.db.migrate! user
      end

      it 'stores and retrieves an image via prepared statement' do
        Swift.db do |db|
          io = File.open(File.dirname(__FILE__) + '/house-explode.jpg')
          db.prepare('insert into users (name, image) values(?, ?)').execute('test', io)

          blob = db.prepare('select image from users limit 1').execute.first[:image]

          io.rewind
          assert_kind_of StringIO, blob

          data = blob.read
          assert_equal Encoding::ASCII_8BIT, data.encoding
          assert_equal io.read.force_encoding('ASCII-8BIT'), data
        end
      end

      it 'stores and retrieves an image via Adapter#execute' do
        Swift.db do |db|
          io = File.open(File.dirname(__FILE__) + '/house-explode.jpg')
          db.execute('insert into users (name, image) values(?, ?)', 'test', io)

          blob = db.prepare('select image from users limit 1').execute.first[:image]

          io.rewind
          assert_kind_of StringIO, blob

          data = blob.read
          assert_equal Encoding::ASCII_8BIT, data.encoding
          assert_equal io.read.force_encoding('ASCII-8BIT'), data
        end
      end
    end
  end
end
