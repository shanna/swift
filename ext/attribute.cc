#include "attribute.h"

VALUE fCall;

VALUE attribute_default(VALUE self) {
  VALUE value = rb_iv_get(self, "@default");

  if (NIL_P(value) || rb_special_const_p(value))
    return value;
  else if (rb_respond_to(value, fCall))
    return rb_funcall(value, fCall, 0);
  else
    return rb_obj_dup(value);
}

void init_swift_attribute() {
  VALUE mSwift          = rb_define_module("Swift");
  VALUE cSwiftAttribute = rb_define_class_under(mSwift, "Attribute", rb_cObject);

  fCall = rb_intern("call");
  rb_define_method(cSwiftAttribute, "default", RUBY_METHOD_FUNC(attribute_default), 0);
}
