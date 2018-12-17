require_relative 'helper'

describe 'record' do
  before do
    @user = Class.new(Swift::Record) do
      store     :users
      attribute :id,         Swift::Type::Integer,  serial: true, key: true
      attribute :name,       Swift::Type::String,   default: "dave"
      attribute :age,        Swift::Type::Integer,  default: 18
      attribute :height,     Swift::Type::Float,    default: 172.25
      attribute :email,      Swift::Type::String
      attribute :verified,   Swift::Type::Boolean,  default: false
      attribute :created_at, Swift::Type::DateTime, default: proc { Time.now }

      migrations do |db|
        db.execute %q{
          create users(id serial, name text, age int, height real, email text, verified bool, created_at timestamp)
        }
      end
    end
  end

  describe 'attributes' do
    it 'defines attributes' do
      user = @user.new
      %w(id name age email created_at).each do |m|
        assert user.respond_to?(m),       "responds to m"
        assert user.respond_to?("#{m}="), "responds to m="
      end
    end
  end

  describe 'instantiation' do
    it 'returns a new instance with defaults' do
      user = @user.new
      assert_kind_of @user, user
      assert_kind_of Time,  user.created_at

      assert_nil user.id
      assert_equal 'dave', user.name
      assert_equal 18,     user.age
      assert_equal 172.25, user.height
      assert_nil user.email
      assert_equal false,  user.verified
    end

    it 'returns a new user' do
      user = @user.new name: 'cary', age: 22, email: 'cary@local'

      assert_kind_of @user, user
      assert_kind_of Time,  user.created_at

      assert_nil user.id
      assert_equal 'cary',       user.name
      assert_equal 22,           user.age
      assert_equal 'cary@local', user.email
    end
  end

  supported_by Swift::Adapter::Postgres, Swift::Adapter::Mysql, Swift::Adapter::Sqlite3 do
    describe 'field name customization' do
      before do
        @user = Class.new(Swift::Record) do
          store     :users
          attribute :id,   Swift::Type::Integer, serial: true, key: true, field: 'field_id'
          attribute :name, Swift::Type::String, field: 'field_name'
        end

        Swift.db.migrate! @user
      end

      it 'should fetch and create by fields correctly' do
        @user.create(name: 'dave')
        user = @user.execute("select * from #{@user} limit 1").first
        assert_equal 'dave', user.name
        assert_equal 1, user.id
      end
    end

    describe 'adapter operations' do
      before do
        Swift.db.migrate! @user
      end

      it 'should return record instance when given record in #execute' do
        user = @user.create
        assert_equal 1, Swift.db.execute(@user, 'select * from users').first.id
      end

      it 'adapter should delete valid instance' do
        user = @user.create
        assert_equal 1, user.id

        assert Swift.db.delete @user, user
        assert_nil @user.get(id: 1)
      end

      it 'adapter should barf when trying to delete an invalid instance' do
        assert_raises(Swift::ArgumentError) { Swift.db.delete @user, {id: nil, name: 'foo'} }
      end

      it 'should not update without valid keys' do
        user = @user.new
        assert_raises(Swift::ArgumentError) { user.update(name: 'dave') }
      end

      it 'should update with valid keys' do
        user = @user.create
        assert user.update(name: 'dave')
        assert_equal 'dave', @user.execute("select * from #{@user}").first.name
      end

      it 'should destroy' do
        user = @user.create
        assert user.update(name: 'dave')
        assert user.delete
      end

      it 'should use Record.load to create new instances from database' do
        klass = Class.new(@user) { def self.load tuple; super.tap {|i| i.tuple[:name] = 'test'}; end }
        user = klass.create(name: 'dan')
        user = klass.get(id: user.id)
        assert_equal 'test', user.name
      end
    end
  end
end
