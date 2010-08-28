#include "statement.h"
#include "adapter.h"
#include "result.h"
#include "query.h"

VALUE cSwiftStatement;

void statement_free(dbi::AbstractStatement *statement) {
  if (statement) {
    statement->cleanup();
    delete statement;
  }
}

VALUE statement_alloc(VALUE klass) {
  dbi::AbstractStatement *statement = 0;
  return Data_Wrap_Struct(klass, 0, statement_free, statement);
}

dbi::AbstractStatement* statement_handle(VALUE self) {
  dbi::AbstractStatement *handle;
  Data_Get_Struct(self, dbi::AbstractStatement, handle);
  if (!handle) rb_raise(eSwiftRuntimeError, "Invalid object, did you forget to call #super?");

  return handle;
}

// TODO: Change bind_values to an array in the interface? Avoid array -> splat -> array.
static VALUE statement_execute(int argc, VALUE *argv, VALUE self) {
  VALUE bind_values, block;
  rb_scan_args(argc, argv, "0*&", &bind_values, &block);

  dbi::AbstractStatement *statement = (dbi::AbstractStatement*)statement_handle(self);
  try {
    Query query;
    query.statement = statement;
    if (RARRAY_LEN(bind_values) > 0) query_bind_values(&query, bind_values);
    if (dbi::_trace)                 dbi::logMessage(dbi::_trace_fd, dbi::formatParams(statement->command(), query.bind));
    rb_thread_blocking_region(((VALUE (*)(void*))query_execute_statement), &query, 0, 0);
  }
  CATCH_DBI_EXCEPTIONS();

  if (rb_block_given_p()) return result_each(self);
  return self;
}

VALUE statement_initialize(VALUE self, VALUE adapter, VALUE sql) {
  dbi::Handle *handle = adapter_handle(adapter);

  if (NIL_P(adapter)) rb_raise(eSwiftArgumentError, "Statement#new called without an Adapter instance.");
  if (NIL_P(sql))     rb_raise(eSwiftArgumentError, "Statement#new called without a command.");

  try {
    DATA_PTR(self) = handle->conn()->prepare(CSTRING(sql));
  }
  CATCH_DBI_EXCEPTIONS();

  return Qnil;
}

void init_swift_statement() {
  VALUE mSwift = rb_define_module("Swift");

  /*
    TODO Inheritance confusion.

    dbic++ has this,
    dbi::Statement < dbi::AbstractStatement
    dbi::AbstractStatement < dbi::AbstractResult

    Swift has this,
    Statement < Result

    Not sure if this hierarchy is correct or perfect. I reckon Statement should not
    inherit Result and just return a Result on execute() - maybe cleaner but very
    inefficient when doing tons on non-select style queries.
  */

  cSwiftStatement = rb_define_class_under(mSwift, "Statement", cSwiftResult);
  rb_define_method(cSwiftStatement, "execute",    RUBY_METHOD_FUNC(statement_execute),   -1);
  rb_define_method(cSwiftStatement, "initialize", RUBY_METHOD_FUNC(statement_initialize), 2);
  rb_define_alloc_func(cSwiftStatement, statement_alloc);
}
