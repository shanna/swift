# TODO remove this once the patch gets applied to stock ruby 1.9
class MiniTest::Spec < MiniTest::Unit::TestCase

  def self.define_inheritable_method name, &block # :nodoc:
    super_method = self.superclass.instance_method name

    case name
      when :teardown
        define_method(name) do
          instance_eval(&block)
          super_method.bind(self).call if super_method
        end
      else
        define_method(name) do
          super_method.bind(self).call if super_method
          instance_eval(&block)
        end
    end
  end
end
