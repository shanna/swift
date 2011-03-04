require_relative 'helper'

describe 'scheme' do
  before do
    @user = Class.new(Swift::Scheme) do
      store     :users
      attribute :id,         Swift::Type::Integer,  serial: true, key: true
      attribute :name,       Swift::Type::String,   default: "dave"
      attribute :age,        Swift::Type::Integer,  default: 18
      attribute :height,     Swift::Type::Float,    default: 172.25
      attribute :email,      Swift::Type::String
      attribute :verified,   Swift::Type::Boolean,  default: false
      attribute :created_at, Swift::Type::Time,     default: proc { Time.now }
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

      assert_equal nil,    user.id
      assert_equal 'dave', user.name
      assert_equal 18,     user.age
      assert_equal 172.25, user.height
      assert_equal nil,    user.email
      assert_equal false,  user.verified
    end

    it 'returns a new user' do
      user = @user.new name: 'cary', age: 22, email: 'cary@local'

      assert_kind_of @user, user
      assert_kind_of Time,  user.created_at

      assert_equal nil,          user.id
      assert_equal 'cary',       user.name
      assert_equal 22,           user.age
      assert_equal 'cary@local', user.email
    end
  end

  supported_by Swift::DB::Postgres, Swift::DB::Mysql, Swift::DB::Sqlite3 do
    describe 'adapter operations' do
      before do
        Swift.db.migrate! @user
      end

      it 'should return scheme instance when given scheme in #execute' do
        user = @user.create
        assert_equal 1, Swift.db.execute(@user, 'select * from users').first.id
      end

      it 'adapter should destroy valid instance' do
        user = @user.create
        assert_equal 1, user.id

        assert Swift.db.destroy @user, user
        assert_nil @user.get(id: 1)
      end

      it 'adapter should barf when trying to destroy invalid instance' do
        assert_raises(ArgumentError) { Swift.db.destroy @user, {id: nil, name: 'foo'} }
      end

      it 'adapter should delete all rows given scheme' do
        user = @user.create
        assert_equal 1, user.id

        Swift.db.delete @user
        assert_nil @user.get(id: 1)
      end

      it 'adapter should delete only relevant rows given condition & scheme' do
        Swift.db.create(@user, [{name: 'dave'}, {name: 'mike'}])
        assert_equal 2, @user.all.rows

        Swift.db.delete @user, ':name = ?', 'dave'
        assert_nil @user.first ':name = ?', 'dave'
        assert @user.first ':name = ?', 'mike'
      end

      it 'should not update without valid keys' do
        user = @user.new
        assert_raises(ArgumentError) { user.update(name: 'dave') }
      end

      it 'should update with valid keys' do
        user = @user.create
        assert user.update(name: 'dave')
        assert_equal 'dave', @user.first.name
      end
    end
  end
end
