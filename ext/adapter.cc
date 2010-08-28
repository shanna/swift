#include "adapter.h"

static VALUE cSwiftAdapter;
VALUE eSwiftConnectionError;

static void adapter_free(dbi::Handle *handle) {
    if (handle) delete handle;
}

VALUE adapter_alloc(VALUE klass) {
    dbi::Handle *handle = 0;
    return Data_Wrap_Struct(klass, 0, adapter_free, handle);
}

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
  rb_raise(eRuntimeError, "clone is not allowed.");
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
  rb_raise(eRuntimeError, "dup is not allowed.");
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
    if (dbi::_trace)                 dbi::logMessage(dbi::_trace_fd, dbi::formatParams(query.sql, query.bind));
    rows = rb_thread_blocking_region(((VALUE (*)(void*))query_execute), &query, 0, 0);

    if (rb_block_given_p()) {
      // TODO: Move into a result_* constructor.
      dbi::AbstractResultSet *rs = handle->results();
      result                     = Data_Wrap_Struct(cSwiftResult, 0, result_free, rs);
      rb_iv_set(result, "@adapter", self);
    }
  }
  CATCH_DBI_EXCEPTIONS();

  return result ? result_each(result) : rows;
}

dbi::Handle* adapter_handle(VALUE self) {
  dbi::Handle *handle;
  Data_Get_Struct(self, dbi::Handle, handle);
  if (!handle) rb_raise(eRuntimeError, "Invalid object, did you forget to call #super?");

  return handle;
}

static VALUE adapter_initialize(VALUE self, VALUE options) {
  VALUE db       = rb_hash_aref(options, ID2SYM(rb_intern("db")));
  VALUE driver   = rb_hash_aref(options, ID2SYM(rb_intern("driver")));
  VALUE user     = rb_hash_aref(options, ID2SYM(rb_intern("user")));

  if (NIL_P(db))     rb_raise(eArgumentError, "Adapter#new called without :db");
  if (NIL_P(driver)) rb_raise(eArgumentError, "Adapter#new called without :driver");

  user = NIL_P(user) ? rb_str_new2(getlogin()) : user;

  try {
    DATA_PTR(self) = new dbi::Handle(
      CSTRING(driver),
      CSTRING(user),
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

static VALUE adapter_prepare(int argc, VALUE *argv, VALUE self) {
  VALUE sql, scheme, prepared;

  rb_scan_args(argc, argv, "11", &scheme, &sql);
  if (TYPE(scheme) != T_CLASS) {
    sql    = scheme;
    scheme = Qnil;
  }

  dbi::Handle *handle = adapter_handle(self);
  try {
    // TODO: Move to statement_* constructor.
    dbi::AbstractStatement *st = handle->conn()->prepare(CSTRING(sql));
    prepared                   = Data_Wrap_Struct(cSwiftStatement, 0, statement_free, st);
    rb_iv_set(prepared, "@adapter", self);
    rb_iv_set(prepared, "@scheme",  scheme);
  }
  CATCH_DBI_EXCEPTIONS();

  return prepared;
}

static VALUE adapter_rollback(int argc, VALUE *argv, VALUE self) {
  VALUE save_point;
  rb_scan_args(argc, argv, "01", &save_point);

  dbi::Handle *handle = adapter_handle(self);
  try {
    NIL_P(save_point) ? handle->rollback() : handle->rollback(CSTRING(save_point));
  }
  CATCH_DBI_EXCEPTIONS();
}

static VALUE adapter_transaction(int argc, VALUE *argv, VALUE self) {
  int status;
  VALUE sp, block;
  rb_scan_args(argc, argv, "01&", &sp, &block);
  if (NIL_P(block)) rb_raise(eArgumentError, "Transaction called without a block.");

  dbi::Handle *handle    = adapter_handle(self);
  std::string save_point = NIL_P(sp) ? "SP" + dbi::generateCompactUUID() : CSTRING(sp);
  try {
    handle->begin(save_point);
    rb_protect(rb_yield, self, &status);
    if (!status && handle->transactions().size() > 0) {
      handle->commit(save_point);
    }
    else if (status && handle->transactions().size() > 0) {
      handle->rollback(save_point);
      rb_jump_tag(status);
    }
  }
  CATCH_DBI_EXCEPTIONS();

  return Qtrue;
}

static VALUE adapter_write(int argc, VALUE *argv, VALUE self) {
  ulong rows = 0;
  VALUE stream, table, fields;
  dbi::Handle *handle = adapter_handle(self);

  rb_scan_args(argc, argv, "30", &table, &fields, &stream);
  if (TYPE(stream) != T_STRING && !rb_respond_to(stream, rb_intern("read")))
    rb_raise(eArgumentError, "Stream must be a String or IO object.");
  if (TYPE(fields) != T_ARRAY)
    rb_raise(eArgumentError, "Fields must be an Array.");

  try {
    dbi::FieldSet write_fields;
    for (int i = 0; i < RARRAY_LEN(fields); i++) {
      VALUE field = TO_S(rb_ary_entry(fields, i));
      write_fields << std::string(RSTRING_PTR(field), RSTRING_LEN(field));
    }

    /*
      TODO: Adapter specific code is balls.
      This is just for the friggin mysql support - mysql does not like a statement close command being send on a
      handle when the writing has started.
    */
    rb_gc();

    if (TYPE(stream) == T_STRING) {
      dbi::IOStream io(RSTRING_PTR(stream), RSTRING_LEN(stream));
      rows = handle->write(RSTRING_PTR(table), write_fields, &io);
    }
    else {
      IOStream io(stream);
      rows = handle->write(RSTRING_PTR(table), write_fields, &io);
    }
  }
  CATCH_DBI_EXCEPTIONS();

  return ULONG2NUM(rows);
}

VALUE adapter_results(VALUE self) {
  dbi::Handle *handle = adapter_handle(self);
  try {
      dbi::AbstractResultSet *result = handle->results();
      return Data_Wrap_Struct(cSwiftResult, 0, result_free, result);
  }
  CATCH_DBI_EXCEPTIONS();
}

void init_swift_adapter() {
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
  rb_define_method(cSwiftAdapter, "prepare",     RUBY_METHOD_FUNC(adapter_prepare),     -1);
  rb_define_method(cSwiftAdapter, "rollback",    RUBY_METHOD_FUNC(adapter_rollback),    -1);
  rb_define_method(cSwiftAdapter, "transaction", RUBY_METHOD_FUNC(adapter_transaction), -1);
  rb_define_method(cSwiftAdapter, "write",       RUBY_METHOD_FUNC(adapter_write),       -1);

  rb_define_alloc_func(cSwiftAdapter, adapter_alloc);

  // TODO Figure out how to avoid race conditions.
  rb_define_method(cSwiftAdapter, "results",     RUBY_METHOD_FUNC(adapter_results),     0);
}


