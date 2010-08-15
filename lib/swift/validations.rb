module Swift
  class Errors < Array
    attr_accessor :relation

    def initialize relation
      @relation = relation
    end
  end # Errors

  class Scheme
    def self.validations &validations
      define_method :validate do
        errors = Errors.new(self)
        instance_exec errors, &validations
        errors
      end
    end

    def validate errors = Errors.new(self)
      errors
    end

    def valid?
      validate.empty?
    end
  end # Scheme
end # Swift
