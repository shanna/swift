#include "adapter.h"

// Extend the default dbi::FieldSet class with some ruby love.
class Fields : public dbi::FieldSet {
  public:
    Fields() : dbi::FieldSet(0) {}

    void operator<<(VALUE v) {
      VALUE name = TO_S(v);
      fields.push_back(std::string(RSTRING_PTR(name), RSTRING_LEN(name)));
    }
};

static VALUE cSwiftAdapter;

void build_extra_options_string(VALUE key, VALUE value, VALUE ptr) {
  std::string *optstring = (std::string *)ptr;
  *optstring += CSTRING(key) + std::string("=") + CSTRING(value) + std::string(";");
}

std::string parse_extra_options(VALUE options) {
  std::string optstring = "";
  if (!NIL_P(options))
    rb_hash_foreach(options, RUBY_STATIC_FUNC(build_extra_options_string), (VALUE)&optstring);
  return optstring;
}

static void adapter_free(dbi::Handle *handle) {
  if (handle) {
    handle->conn()->cleanup();
    delete handle;
  }
}

VALUE adapter_alloc(VALUE klass) {
  dbi::Handle *handle = 0;
  return Data_Wrap_Struct(klass, 0, adapter_free, handle);
}

dbi::Handle* adapter_handle(VALUE self) {
  dbi::Handle *handle;
  Data_Get_Struct(self, dbi::Handle, handle);
  if (!handle) rb_raise(eSwiftRuntimeError, "Invalid object, did you forget to call #super?");

  return handle;
}

/*
  Begin a transaction (unit of work).

  @overload commit(name = nil)
    @param [Symbol, String] name Optional transaction name.

  @see Swift::Adapter#transaction
*/
static VALUE adapter_begin(int argc, VALUE *argv, VALUE self) {
  VALUE save_point;
  rb_scan_args(argc, argv, "01", &save_point);

  dbi::Handle *handle = adapter_handle(self);
  try {
    NIL_P(save_point) ? handle->begin() : handle->begin(CSTRING(save_point));
  }
  CATCH_DBI_EXCEPTIONS();
  return Qtrue;
}

/*
  Close the connection.
*/
static VALUE adapter_close(VALUE self) {
  dbi::Handle *handle = adapter_handle(self);
  try { handle->close(); } CATCH_DBI_EXCEPTIONS();
  rb_iv_set(self, "@closed", true);
  return Qtrue;
}


/*
  Check if connection is closed.
*/
static VALUE adapter_closed(VALUE self) {
  return rb_iv_get(self, "@closed");
}




/*
  Shallow copy of adapter.

  @note Currently not allowed.
  @see  Object.clone
*/
static VALUE adapter_clone(VALUE self) {
  rb_raise(eSwiftRuntimeError, "clone is not allowed.");
}

/*
  Commit a transaction (unit of work).

  @overload commit(name = nil)
    @param [Symbol, String] name Optional transaction name.
*/
static VALUE adapter_commit(int argc, VALUE *argv, VALUE self) {
  VALUE save_point;
  rb_scan_args(argc, argv, "01", &save_point);
  dbi::Handle *handle = adapter_handle(self);

  try {
    NIL_P(save_point) ? handle->commit() : handle->commit(CSTRING(save_point));
  }
  CATCH_DBI_EXCEPTIONS();
  return Qtrue;
}

/*
  Shallow copy of adapter.

  @note Currently not allowed.
  @see  Object.dup
*/
static VALUE adapter_dup(VALUE self) {
  rb_raise(eSwiftRuntimeError, "dup is not allowed.");
}

/*
  Escape a string.

  @note Bind values do not need to be escaped.

  @overload escape(value)
    @param  [String] value String to be escaped.
    @return [String]
*/
static VALUE adapter_escape(VALUE self, VALUE value) {
  if (TYPE(value) != T_STRING)
    value = TO_S(value);

  dbi::Handle *handle = adapter_handle(self);
  try {
    std::string safe = handle->escape(std::string(RSTRING_PTR(value), RSTRING_LEN(value)));
    return rb_str_new(safe.data(), safe.length());
  }
  CATCH_DBI_EXCEPTIONS();
}

/*
  Execute a single statement.

  @example
    result = User.execute("select * from #{User} where #{User.name} = ?", 'apple')
    result.first # User object.

  @overload execute(statement = '', *binds, &block)
    @param  [String]  statement Query statement.
    @param  [*Object] binds     Bind values.
    @yield  [Swift::Result]
    @return [Swift::Result]
*/
static VALUE adapter_execute(int argc, VALUE *argv, VALUE self) {
  VALUE statement, bind_values, block, rows, scheme = Qnil;

  dbi::Handle *handle = adapter_handle(self);
  rb_scan_args(argc, argv, "1*&", &statement, &bind_values, &block);

  if (TYPE(statement) == T_CLASS) {
    scheme    = statement;
    statement = rb_ary_shift(bind_values);
  }

  try {
    Query query;
    query.sql    = CSTRING(statement);
    query.handle = handle;

    if (RARRAY_LEN(bind_values) > 0) query_bind_values(&query, bind_values);
    if (dbi::_trace)                 dbi::logMessage(dbi::_trace_fd, dbi::formatParams(query.sql, query.bind));

    if ((rows = rb_thread_blocking_region(((VALUE (*)(void*))query_execute), &query, RUBY_UBF_IO, 0)) == Qfalse)
      rb_raise(query.error_klass, "%s", query.error_message);

    VALUE result = result_wrap_handle(cSwiftResult, self, handle->conn()->result(), true);
    if (!NIL_P(scheme))
      rb_iv_set(result, "@scheme", scheme);
    return rb_block_given_p() ? result_each(result) : result;
  }
  CATCH_DBI_EXCEPTIONS();
}

/*
  Reestablish a connection.
*/
static VALUE adapter_reconnect(VALUE self) {
  dbi::Handle *handle = adapter_handle(self);
  try {
    handle->reconnect();
    rb_iv_set(self, "@closed", false);
  }
  CATCH_DBI_EXCEPTIONS();
  return Qtrue;
}

/*
  Setup a new DB connection.

  You almost certainly want to setup a <tt>:default</tt> named adapter. The <tt>:default</tt> scope will be used
  for unscoped calls to <tt>Swift.db</tt>.

  @example
    Swift.setup :default, Swift::DB::Postgres, db: 'db1'
    Swift.setup :other,   Swift::DB::Postgres, db: 'db2'

  @overload new(options = {})
    @param  [Hash]           options Connection options
    @option options [String]  :db       Name.
    @option options [String]  :user     (*nix login user)
    @option options [String]  :password ('')
    @option options [String]  :host     ('localhost')
    @option options [Integer] :port     (DB default)
    @option options [String]  :timezone (*nix TZ format) See http://en.wikipedia.org/wiki/List_of_tz_database_time_zones
    @return [Swift::Adapter]

  @see Swift::DB
  @see Swift::Adapter
*/
static VALUE adapter_initialize(VALUE self, VALUE options) {
  VALUE db       = rb_hash_aref(options, ID2SYM(rb_intern("db")));
  VALUE driver   = rb_hash_aref(options, ID2SYM(rb_intern("driver")));
  VALUE user     = rb_hash_aref(options, ID2SYM(rb_intern("user")));

  if (NIL_P(db))     rb_raise(eSwiftArgumentError, "Adapter#new called without :db");
  if (NIL_P(driver)) rb_raise(eSwiftArgumentError, "Adapter#new called without :driver");

  user           = NIL_P(user) ? current_user() : user;
  VALUE extra    = rb_hash_dup(options);

  rb_hash_delete(extra, ID2SYM(rb_intern("db")));
  rb_hash_delete(extra, ID2SYM(rb_intern("driver")));
  rb_hash_delete(extra, ID2SYM(rb_intern("user")));
  rb_hash_delete(extra, ID2SYM(rb_intern("password")));
  rb_hash_delete(extra, ID2SYM(rb_intern("host")));
  rb_hash_delete(extra, ID2SYM(rb_intern("port")));
  rb_hash_delete(extra, ID2SYM(rb_intern("timezone")));

  std::string extra_options_string = parse_extra_options(extra);

  try {
    DATA_PTR(self) = new dbi::Handle(
      CSTRING(driver),
      CSTRING(user),
      CSTRING(rb_hash_aref(options, ID2SYM(rb_intern("password")))),
      CSTRING(db),
      CSTRING(rb_hash_aref(options, ID2SYM(rb_intern("host")))),
      CSTRING(rb_hash_aref(options, ID2SYM(rb_intern("port")))),
      extra_options_string.size() > 0 ? (char*)extra_options_string.c_str() : 0
    );
  }
  CATCH_DBI_EXCEPTIONS();

  rb_iv_set(self, "@options",  options);
  rb_iv_set(self, "@timezone", rb_hash_aref(options, ID2SYM(rb_intern("timezone"))));

  return Qnil;
}

/*
  Prepare a statement for on or more executions.

  @example
    sth = User.prepare("select * from #{User} where #{User.name} = ?")
    sth.execute('apple') #=> Result
    sth.execute('benny') #=> Result

  @overload prepare(statement, &block)
    @param  [String] statement Query statement.
    @return [Swift::Statement]
*/
static VALUE adapter_prepare(int argc, VALUE *argv, VALUE self) {
  VALUE sql, scheme, prepared;
  dbi::AbstractStatement *statement;

  rb_scan_args(argc, argv, "11", &scheme, &sql);
  if (TYPE(scheme) != T_CLASS) {
    sql    = scheme;
    scheme = Qnil;
  }

  dbi::Handle *handle = adapter_handle(self);
  try {
    // TODO: Move to statement_* constructor.
    statement = handle->conn()->prepare(CSTRING(sql));
    prepared  = statement_wrap_handle(cSwiftStatement, self, statement);
    rb_iv_set(prepared, "@scheme",  scheme);
    rb_iv_set(prepared, "@sql",     sql);
    return prepared;
  }
  CATCH_DBI_EXCEPTIONS();
}

/*
  Rollback the current transaction.

  @overload rollback(name = nil)
    @param [Symbol, String] name Optional transaction name.
*/
static VALUE adapter_rollback(int argc, VALUE *argv, VALUE self) {
  VALUE save_point;
  dbi::Handle *handle = adapter_handle(self);
  rb_scan_args(argc, argv, "01", &save_point);

  try {
    NIL_P(save_point) ? handle->rollback() : handle->rollback(CSTRING(save_point));
  }
  CATCH_DBI_EXCEPTIONS();
  return Qtrue;
}

/*
  Block form transaction sugar.

  @overload transaction(name = nil, &block)
    @param [Symbol, String] name Optional transaction name.
*/
static VALUE adapter_transaction(int argc, VALUE *argv, VALUE self) {
  int status;
  VALUE sp, block, block_result = Qnil;
  dbi::Handle *handle = adapter_handle(self);
  rb_scan_args(argc, argv, "01&", &sp, &block);

  if (NIL_P(block)) rb_raise(eSwiftArgumentError, "Transaction called without a block.");
  std::string save_point = NIL_P(sp) ? "SP" + dbi::generateCompactUUID() : CSTRING(sp);

  try {
    handle->begin(save_point);
    block_result = rb_protect(rb_yield, self, &status);
    if (!status && handle->transactions().size() > 0) {
      handle->commit(save_point);
    }
    else if (status && handle->transactions().size() > 0) {
      handle->rollback(save_point);
      rb_jump_tag(status);
    }
  }
  CATCH_DBI_EXCEPTIONS();

  return block_result;
}

/*
  Bulk insert resources.

  @overload write(store, fields, stream)
    @param [Swift::Scheme, String]           store  Write to store.
    @param [Array<Swift::Attribute, String>] fields Write to fields in store.
    @param [IO]                              stream IO to read from.

  @note The format of the stream and bulk write performance are entirely down to each adapter.
*/
static VALUE adapter_write(int argc, VALUE *argv, VALUE self) {
  uint64_t rows = 0;
  VALUE stream, table, fields;
  dbi::Handle *handle = adapter_handle(self);

  rb_scan_args(argc, argv, "30", &table, &fields, &stream);
  if (TYPE(stream) != T_STRING && !rb_respond_to(stream, rb_intern("read")))
    rb_raise(eSwiftArgumentError, "Stream must be a String or IO object.");
  if (TYPE(fields) != T_ARRAY)
    rb_raise(eSwiftArgumentError, "Fields must be an Array.");

  try {
    Fields write_fields;
    for (int i = 0; i < RARRAY_LEN(fields); i++)
      write_fields << rb_ary_entry(fields, i);

    /*
      TODO: Adapter specific code is balls.
      This is just for the friggin mysql support - mysql does not like a statement close command being send on a
      handle when the writing has started.
    */
    rb_gc();

    if (TYPE(stream) == T_STRING) {
      dbi::StringIO io(RSTRING_PTR(stream), RSTRING_LEN(stream));
      rows = handle->write(RSTRING_PTR(TO_S(table)), write_fields, &io);
    }
    else {
      AdapterIO io(stream);
      rows = handle->write(RSTRING_PTR(TO_S(table)), write_fields, &io);
    }
    return SIZET2NUM(rows);
  }
  CATCH_DBI_EXCEPTIONS();
}

void init_swift_adapter() {
  VALUE mSwift   = rb_define_module("Swift");
  cSwiftAdapter = rb_define_class_under(mSwift, "Adapter", rb_cObject);

  rb_define_method(cSwiftAdapter, "begin",       RUBY_METHOD_FUNC(adapter_begin),       -1);
  rb_define_method(cSwiftAdapter, "clone",       RUBY_METHOD_FUNC(adapter_clone),        0);
  rb_define_method(cSwiftAdapter, "close",       RUBY_METHOD_FUNC(adapter_close),        0);
  rb_define_method(cSwiftAdapter, "closed?",     RUBY_METHOD_FUNC(adapter_closed),       0);
  rb_define_method(cSwiftAdapter, "commit",      RUBY_METHOD_FUNC(adapter_commit),      -1);
  rb_define_method(cSwiftAdapter, "dup",         RUBY_METHOD_FUNC(adapter_dup),          0);
  rb_define_method(cSwiftAdapter, "escape",      RUBY_METHOD_FUNC(adapter_escape),       1);
  rb_define_method(cSwiftAdapter, "execute",     RUBY_METHOD_FUNC(adapter_execute),     -1);
  rb_define_method(cSwiftAdapter, "initialize",  RUBY_METHOD_FUNC(adapter_initialize),   1);
  rb_define_method(cSwiftAdapter, "prepare",     RUBY_METHOD_FUNC(adapter_prepare),     -1);
  rb_define_method(cSwiftAdapter, "rollback",    RUBY_METHOD_FUNC(adapter_rollback),    -1);
  rb_define_method(cSwiftAdapter, "transaction", RUBY_METHOD_FUNC(adapter_transaction), -1);
  rb_define_method(cSwiftAdapter, "write",       RUBY_METHOD_FUNC(adapter_write),       -1);
  rb_define_method(cSwiftAdapter, "reconnect",   RUBY_METHOD_FUNC(adapter_reconnect),    0);

  rb_define_alloc_func(cSwiftAdapter, adapter_alloc);
}

