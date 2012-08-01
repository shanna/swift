require_relative 'helper'
require 'swift/validations'

describe 'validations' do
  before do
    @user = Class.new(Swift::Record) do
      store     :users
      attribute :id,   Swift::Type::Integer, serial: true, key: true
      attribute :name, Swift::Type::String

      validations do |errors|
        errors << [:name, 'is blank'] if name.to_s.empty?
      end
    end
  end

  describe 'validate' do
    it 'returns errors' do
      assert_kind_of Swift::Errors, @user.new.validate
    end

    it 'has errors when invalid' do
      assert !@user.new.validate.empty?
    end

    it 'has no errors when valid' do
      assert @user.new(name: 'Apple Arthurton').validate.empty?
    end
  end

  describe 'valid?' do
    it 'fails when invalid' do
      assert !@user.new.valid?
    end

    it 'passes when valid' do
      assert @user.new(name: 'Apple Arthurton').valid?
    end
  end

  describe 'errors' do
    it 'has relation' do
      assert_kind_of Swift::Record, @user.new.validate.relation
    end
  end
end
