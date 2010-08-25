#include "statement.h"

VALUE cSwiftStatement;

void statement_free(dbi::AbstractStatement *self) {
  if (self) {
    self->cleanup();
    delete self;
  }
}

void init_swift_statement() {
  VALUE swift     = rb_define_module("Swift");
  cSwiftStatement = rb_define_class_under(swift, "Statement", rb_cObject);
}
