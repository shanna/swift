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
end
