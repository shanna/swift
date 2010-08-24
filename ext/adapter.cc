#include "adapter.h"

static VALUE cSwiftAdapter;
static VALUE eSwiftConnectionError;

static VALUE eArgumentError;
static VALUE eRuntimeError;
static VALUE eStandardError;

static VALUE adapter_begin(int argc, VALUE *argv, VALUE self) {
  VALUE save_point;
  rb_scan_args(argc, argv, "01", &save_point);

  dbi::Handle *handle = adapter_handle(self);
  try {
    NIL_P(save_point) ? handle->begin() : handle->begin(CSTRING(save_point));
  }
  CATCH_DBI_EXCEPTIONS();
}

static VALUE adapter_close(VALUE self) {
  dbi::Handle *handle = adapter_handle(self);
  try { handle->close(); } CATCH_DBI_EXCEPTIONS();
  return Qtrue;
}

// TODO:
static VALUE adapter_clone(VALUE self) {
  rb_raise(eRuntimeError, "Adapter#clone is not allowed.");
}

static VALUE adapter_commit(int argc, VALUE *argv, VALUE self) {
  VALUE save_point;
  rb_scan_args(argc, argv, "01", &save_point);
  dbi::Handle *handle = adapter_handle(self);

  try {
    NIL_P(save_point) ? handle->commit() : handle->commit(CSTRING(save_point));
  }
  CATCH_DBI_EXCEPTIONS();
}

// TODO:
static VALUE adapter_dup(VALUE self) {
  rb_raise(eRuntimeError, "Adapter#dup is not allowed.");
}

// TODO: Attempt TO_S() before escaping?
static VALUE adapter_escape(VALUE self, VALUE value) {
  VALUE escaped = Qnil;
  if (TYPE(value) != T_STRING) rb_raise(eArgumentError, "Cannot escape non-string value.");

  dbi::Handle *handle = adapter_handle(self);
  try {
    std::string safe = handle->escape(std::string(RSTRING_PTR(value), RSTRING_LEN(value)));
    escaped          = rb_str_new(safe.data(), safe.length());
  }
  CATCH_DBI_EXCEPTIONS();

  return escaped;
}

// TODO: Change bind_values to an array in the interface? Avoid array -> splat -> array.
static VALUE adapter_execute(int argc, VALUE *argv, VALUE self) {
  VALUE statement, bind_values, block, rows;
  VALUE result = 0;

  rb_scan_args(argc, argv, "1*&", &statement, &bind_values, &block);

  dbi::Handle *handle = adapter_handle(self);
  try {
    Query query;
    query.sql    = CSTRING(statement);
    query.handle = handle;
    if (RARRAY_LEN(bind_values) > 0) query_bind_values(&query, bind_values);
    if (dbi::_trace)                 dbi::logMessage(dbi::_trace_fd, query.sql);
    rows = rb_thread_blocking_region(((VALUE (*)(void*)) query_execute), &query, 0, 0);

    if (rb_block_given_p()) {
      dbi::AbstractResultSet *rs = handle->results();
      /*
      TODO: Swift::Result, Swift::Statement ...
      result = Data_Wrap_Struct(cResultSet, 0, free_statement, rs);

      // TODO: Breaks encapsulation. Eventually you'll want to hand over either the adapter or the timezone as part
      // of a constructor for Results.
      rb_iv_set(result, "@timezone", rb_iv_get(self, "@timezone"));
      */
    }
  }
  CATCH_DBI_EXCEPTIONS();

  // TODO: statement_each in statement.{cc|h}
  return rows;
  // return result ? rb_statement_each(result) : rows;
}

dbi::Handle* adapter_handle(VALUE self) {
  dbi::Handle *handle;
  Data_Get_Struct(self, dbi::Handle, handle);
  if (!handle) rb_raise(eRuntimeError, "Invalid object, did you forget to call #super?");

  return handle;
}

static VALUE adapter_initialize(VALUE self, VALUE options) {
  VALUE db     = rb_hash_aref(options, ID2SYM(rb_intern("db")));
  VALUE driver = rb_hash_aref(options, ID2SYM(rb_intern("driver")));

  if (NIL_P(db))     rb_raise(eArgumentError, "Adapter#new called without :db");
  if (NIL_P(driver)) rb_raise(eArgumentError, "Adapter#new called without :driver");

  try {
    DATA_PTR(self) = new dbi::Handle(
      CSTRING(driver),
      CSTRING(rb_hash_aref(options, ID2SYM(rb_intern("user")))),
      CSTRING(rb_hash_aref(options, ID2SYM(rb_intern("password")))),
      CSTRING(db),
      CSTRING(rb_hash_aref(options, ID2SYM(rb_intern("host")))),
      CSTRING(rb_hash_aref(options, ID2SYM(rb_intern("port"))))
    );
  }
  CATCH_DBI_EXCEPTIONS();

  rb_iv_set(self, "@options", options);
  return Qnil;
}

void init_swift_adapter() {
  eArgumentError = CONST_GET(rb_mKernel, "ArgumentError");
  eStandardError = CONST_GET(rb_mKernel, "StandardError");
  eRuntimeError  = CONST_GET(rb_mKernel, "RuntimeError");

  VALUE swift           = rb_define_module("Swift");
  cSwiftAdapter         = rb_define_class_under(swift, "Adapter",         rb_cObject);
  eSwiftConnectionError = rb_define_class_under(swift, "ConnectionError", eRuntimeError);

  rb_define_method(cSwiftAdapter, "begin",       RUBY_METHOD_FUNC(adapter_begin),       -1);
  rb_define_method(cSwiftAdapter, "clone",       RUBY_METHOD_FUNC(adapter_clone),       0);
  rb_define_method(cSwiftAdapter, "close",       RUBY_METHOD_FUNC(adapter_close),       0);
  rb_define_method(cSwiftAdapter, "commit",      RUBY_METHOD_FUNC(adapter_commit),      -1);
  rb_define_method(cSwiftAdapter, "dup",         RUBY_METHOD_FUNC(adapter_dup),         0);
  rb_define_method(cSwiftAdapter, "escape",      RUBY_METHOD_FUNC(adapter_escape),      1);
  rb_define_method(cSwiftAdapter, "execute",     RUBY_METHOD_FUNC(adapter_execute),     -1);
  rb_define_method(cSwiftAdapter, "initialize",  RUBY_METHOD_FUNC(adapter_initialize),  1);
  /*
  TODO:
  rb_define_method(cSwiftAdapter, "prepare",     RUBY_METHOD_FUNC(adapter_prepare),     -1);
  rb_define_method(cSwiftAdapter, "rollback",    RUBY_METHOD_FUNC(adapter_rollback),    -1);
  rb_define_method(cSwiftAdapter, "transaction", RUBY_METHOD_FUNC(adapter_transaction), -1);
  rb_define_method(cSwiftAdapter, "write",       RUBY_METHOD_FUNC(adapter_write),       -1);

  // TODO: Deprecate? Seems risky.
  rb_define_method(cSwiftAdapter, "results",     RUBY_METHOD_FUNC(adapter_results),     0);
  */
}


