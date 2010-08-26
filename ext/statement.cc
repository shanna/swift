#include "statement.h"

VALUE cSwiftStatement;

void statement_free(dbi::Statement *statement) {
  if (statement) {
    statement->cleanup();
    delete statement;
  }
}

void init_swift_statement() {
  VALUE swift     = rb_define_module("Swift");

  // Confusing but (prepared) Statement inherits from ResultSet which inherits from AbstractStatement.
  cSwiftStatement = rb_define_class_under(swift, "Statement", cSwiftResult);
}

