require_relative 'helper'

describe 'scheme' do
  before do
    @user = Class.new(Swift::Scheme) do
      store     :users
      attribute :id,         Swift::Type::Integer, serial: true, key: true
      attribute :name,       Swift::Type::String,  default: "dave"
      attribute :age,        Swift::Type::Integer, default: 18
      attribute :email,      Swift::Type::String
      attribute :created_at, Swift::Type::Time,    default: proc { Time.now }
    end
  end

  describe 'attributes' do
    it 'defines attributes' do
      instance = @user.new
      %w(id name age email created_at).each do |m|
        assert instance.respond_to?(m),       "responds to m"
        assert instance.respond_to?("#{m}="), "responds to m="
      end
    end
  end

  describe 'instantiation' do
    it 'returns a new instance with defaults' do
      instance = @user.new
      assert_kind_of @user, instance
      assert_kind_of Time,  instance.created_at

      assert_equal nil,    instance.id
      assert_equal 'dave', instance.name
      assert_equal 18,     instance.age
      assert_equal nil,    instance.email
    end

    it 'returns a new instance' do
      instance = @user.new name: 'cary', age: 22, email: 'cary@local'

      assert_kind_of @user, instance
      assert_kind_of Time,  instance.created_at

      assert_equal nil,          instance.id
      assert_equal 'cary',       instance.name
      assert_equal 22,           instance.age
      assert_equal 'cary@local', instance.email
    end
  end
end
