#include <dbic++.h>
#include <ruby/ruby.h>
#include <ruby/io.h>
#include <time.h>
#include <pcrecpp.h>

#define CONST_GET(scope, constant) rb_const_get(scope, rb_intern(constant))

static VALUE mSwift;
static VALUE mDBI;
static VALUE cHandle;
static VALUE cStatement;
static VALUE cResultSet;
static VALUE cPool;
static VALUE cRequest;
static VALUE cBigDecimal;

static VALUE eRuntimeError;
static VALUE eArgumentError;
static VALUE eStandardError;
static VALUE eConnectionError;
static VALUE fStringify;
static VALUE fNew;

char errstr[8192];
static time_t tzoffset;
static pcrecpp::RE tm_cleanup_regex("(\\.\\d+)(\\+\\d+)?");

#define CSTRING(v) RSTRING_PTR(TYPE(v) == T_STRING ? v : rb_funcall(v, fStringify, 0))
#define TO_STRING(v) (TYPE(v) == T_STRING ? v : rb_funcall(v, fStringify, 0))

#define EXCEPTION(type) (dbi::ConnectionError &e) { \
    snprintf(errstr, 4096, "%s", e.what()); \
    rb_raise(eConnectionError, "%s : %s", type, errstr); \
} \
catch (dbi::Error &e) {\
    snprintf(errstr, 4096, "%s", e.what()); \
    rb_raise(eRuntimeError, "%s : %s", type, errstr); \
}

static dbi::Handle* DBI_HANDLE(VALUE self) {
    dbi::Handle *h;
    Data_Get_Struct(self, dbi::Handle, h);
    if (!h) rb_raise(eRuntimeError, "Invalid object, did you forget to call #super ?");
    return h;
}

static dbi::AbstractStatement* DBI_STATEMENT(VALUE self) {
    dbi::AbstractStatement *st;
    Data_Get_Struct(self, dbi::AbstractStatement, st);
    if (!st) rb_raise(eRuntimeError, "Invalid object, did you forget to call #super ?");
    return st;
}

static dbi::ConnectionPool* DBI_CPOOL(VALUE self) {
    dbi::ConnectionPool *cp;
    Data_Get_Struct(self, dbi::ConnectionPool, cp);
    if (!cp) rb_raise(eRuntimeError, "Invalid object, did you forget to call #super ?");
    return cp;
}

static dbi::Request* DBI_REQUEST(VALUE self) {
    dbi::Request *r;
    Data_Get_Struct(self, dbi::Request, r);
    if (!r) rb_raise(eRuntimeError, "Invalid object, did you forget to call #super ?");
    return r;
}

void static inline rb_extract_bind_params(int argc, VALUE* argv, std::vector<dbi::Param> &bind) {
    for (int i = 0; i < argc; i++) {
        VALUE arg = argv[i];
        if (arg == Qnil)
            bind.push_back(dbi::PARAM(dbi::null()));
        else {
            arg = TO_STRING(arg);
            bind.push_back(dbi::PARAM_BINARY((unsigned char*)RSTRING_PTR(arg), RSTRING_LEN(arg)));
        }
    }
}

VALUE rb_dbi_init(VALUE self, VALUE path) {
    try { dbi::dbiInitialize(CSTRING(path)); } catch EXCEPTION("DBI#init");
    return Qtrue;
}

static void free_connection(dbi::Handle *self) {
    if (self) delete self;
}

VALUE rb_handle_alloc(VALUE klass) {
    dbi::Handle *h = 0;
    return Data_Wrap_Struct(klass, NULL, free_connection, h);
}

VALUE rb_handle_init(VALUE self, VALUE opts) {
    VALUE db       = rb_hash_aref(opts, ID2SYM(rb_intern("db")));
    VALUE host     = rb_hash_aref(opts, ID2SYM(rb_intern("host")));
    VALUE port     = rb_hash_aref(opts, ID2SYM(rb_intern("port")));
    VALUE user     = rb_hash_aref(opts, ID2SYM(rb_intern("user")));
    VALUE driver   = rb_hash_aref(opts, ID2SYM(rb_intern("driver")));
    VALUE password = rb_hash_aref(opts, ID2SYM(rb_intern("password")));

    if (NIL_P(db)) rb_raise(eArgumentError, "Handle#new called without :db");
    if (NIL_P(user)) rb_raise(eArgumentError, "Handle#new called without :user");
    if (NIL_P(driver)) rb_raise(eArgumentError, "Handle#new called without :driver");

    host     = NIL_P(host)     ? rb_str_new2("") : host;
    port     = NIL_P(port)     ? rb_str_new2("") : port;
    password = NIL_P(password) ? rb_str_new2("") : password;

    try {
        DATA_PTR(self) = new dbi::Handle(
            CSTRING(driver), CSTRING(user), CSTRING(password),
            CSTRING(db), CSTRING(host), CSTRING(port)
        );
    } catch EXCEPTION("Handle#new");

    return Qnil;
}

static void free_statement(dbi::AbstractStatement *self) {
    if (self) {
        self->cleanup();
        delete self;
    }
}

static VALUE rb_handle_prepare(VALUE self, VALUE sql) {
    dbi::Handle *h = DBI_HANDLE(self);
    VALUE rv;
    try {
        dbi::AbstractStatement *st = h->conn()->prepare(CSTRING(sql));
        rv = Data_Wrap_Struct(cStatement, NULL, free_statement, st);
    } catch EXCEPTION("Handle#prepare");
    return rv;
}

VALUE rb_handle_execute(int argc, VALUE *argv, VALUE self) {
    unsigned int rows = 0;
    dbi::Handle *h = DBI_HANDLE(self);
    if (argc == 0 || NIL_P(argv[0]))
        rb_raise(eArgumentError, "Handle#execute called without a SQL command");
    try {
        if (argc == 1) {
            rows = h->execute(CSTRING(argv[0]));
        }
        else {
            dbi::ResultRow bind;
            rb_extract_bind_params(argc-1, argv+1, bind);
            dbi::AbstractStatement *st = h->conn()->prepare(CSTRING(argv[0]));
            if (dbi::_trace)
                dbi::logMessage(dbi::_trace_fd, dbi::formatParams(CSTRING(argv[0]), bind));
            rows = st->execute(bind);
            delete st;
        }
    } catch EXCEPTION("Handle#execute");
    return INT2NUM(rows);
}

VALUE rb_handle_begin(int argc, VALUE *argv, VALUE self) {
    dbi::Handle *h = DBI_HANDLE(self);
    VALUE save;
    rb_scan_args(argc, argv, "01", &save);
    try { NIL_P(save) ? h->begin() : h->begin(CSTRING(save)); } catch EXCEPTION("Handle#begin");
}

VALUE rb_handle_commit(int argc, VALUE *argv, VALUE self) {
    dbi::Handle *h = DBI_HANDLE(self);
    VALUE save;
    rb_scan_args(argc, argv, "01", &save);
    try { NIL_P(save) ? h->commit() : h->commit(CSTRING(save)); } catch EXCEPTION("Handle#commit");
}

VALUE rb_handle_rollback(int argc, VALUE *argv, VALUE self) {
    dbi::Handle *h = DBI_HANDLE(self);
    VALUE save_point;
    rb_scan_args(argc, argv, "01", &save_point);
    try { NIL_P(save_point) ? h->rollback() : h->rollback(CSTRING(save_point)); } catch EXCEPTION("Handle#rollback");
}

VALUE rb_handle_transaction(int argc, VALUE *argv, VALUE self) {
    int status;
    VALUE sp, block;
    rb_scan_args(argc, argv, "01&", &sp, &block);

    std::string save_point = NIL_P(sp) ? "SP" + dbi::generateCompactUUID() : CSTRING(sp);
    dbi::Handle *h         = DBI_HANDLE(self);

    try {
        h->begin(save_point);
        rb_protect(rb_yield, self, &status);
        if (status == 0 && h->transactions().back() == save_point) {
            h->commit(save_point);
        }
        else if (status != 0) {
            if (h->transactions().back() == save_point) h->rollback(save_point);
            rb_jump_tag(status);
        }
    } catch EXCEPTION("Handle#transaction{}");
}

VALUE rb_statement_alloc(VALUE klass) {
    dbi::AbstractStatement *st = 0;
    return Data_Wrap_Struct(klass, NULL, free_statement, st);
}

VALUE rb_statement_init(VALUE self, VALUE hl, VALUE sql) {
    dbi::Handle *h = DBI_HANDLE(hl);

    if (NIL_P(hl) || !h)
        rb_raise(eArgumentError, "Statement#new called without a Handle instance");
    if (NIL_P(sql))
        rb_raise(eArgumentError, "Statement#new called without a SQL command");

    try {
        DATA_PTR(self) = h->conn()->prepare(CSTRING(sql));
    } catch EXCEPTION("Statement#new");

    return Qnil;
}

static VALUE rb_statement_each(VALUE self);

VALUE rb_statement_execute(int argc, VALUE *argv, VALUE self) {
    dbi::AbstractStatement *st = DBI_STATEMENT(self);
    try {
        if (argc == 0) {
            dbi::ResultRow params;
            if (dbi::_trace)
                dbi::logMessage(dbi::_trace_fd, dbi::formatParams(st->command(), params));
            st->execute();
        }
        else {
            dbi::ResultRow bind;
            rb_extract_bind_params(argc, argv, bind);
            if (dbi::_trace)
                dbi::logMessage(dbi::_trace_fd, dbi::formatParams(st->command(), bind));
            st->execute(bind);
        }
    } catch EXCEPTION("Statement#execute");

    if (rb_block_given_p()) return rb_statement_each(self);
    return self;
}

VALUE rb_statement_finish(VALUE self) {
    dbi::AbstractStatement *st = DBI_STATEMENT(self);
    try {
        st->finish();
    } catch EXCEPTION("Statement#finish");
}

VALUE rb_statement_rows(VALUE self) {
    unsigned int rows;
    dbi::AbstractStatement *st = DBI_STATEMENT(self);
    try { rows = st->rows(); } catch EXCEPTION("Statement#rows");
    return INT2NUM(rows);
}

VALUE rb_statement_insert_id(VALUE self) {
  dbi::AbstractStatement *st = DBI_STATEMENT(self);
  VALUE insert_id    = Qnil;
  try {
    if (st->rows() > 0) insert_id = LONG2NUM(st->lastInsertID());
  } catch EXCEPTION("Statement#insert_id");

  return insert_id;
}

VALUE rb_field_typecast(int type, const char *data, unsigned long len) {
    double usec;
    time_t epoch, offset;
    struct tm tm;
    string time_str, offset_str, offset_hour, offset_min;

    switch(type) {
        case DBI_TYPE_INT:
            return rb_cstr2inum(data, 10);
        case DBI_TYPE_TEXT:
            return rb_str_new(data, len);
        case DBI_TYPE_TIME:
            usec       = 0;
            time_str   = data;
            offset_str = "+0000";
            memset(&tm, 0, sizeof(struct tm));
            if (tm_cleanup_regex.PartialMatch(time_str, &usec, &offset_str))
                tm_cleanup_regex.Replace("", &time_str);
            if (strptime(time_str.c_str(), "%F %T", &tm)) {
                offset = 0;
                epoch  = mktime(&tm);
                const char *offset_ptr = offset_str.c_str() + 1;
                if (strcmp(offset_ptr, "0000") != 0 && strcmp(offset_ptr, "00") != 0) {
                    offset_hour = offset_str.substr(1, 2);
                    offset_min  = offset_str.substr(3, 2);
                    offset      = offset_str[0] == '+' ?
                          atol(offset_hour.c_str()) * -3600 + atol(offset_min.c_str()) * -60
                        : atol(offset_hour.c_str()) * 3600  + atol(offset_min.c_str()) * 60;
                    offset      += tzoffset;
                }
                return rb_time_new(epoch + offset, usec*1000000);
            }
            else {
                fprintf(stderr, "typecast failed to parse date: %s\n", data);
                return rb_str_new(data, len);
            }
        // does bigdecimal solve all floating point woes ? dunno :)
        case DBI_TYPE_NUMERIC:
            return rb_funcall(cBigDecimal, fNew, 1, rb_str_new2(data));
        case DBI_TYPE_FLOAT:
            return rb_float_new(atof(data));
    }
}

static VALUE rb_statement_each(VALUE self) {
    unsigned int r, c;
    unsigned long len;
    const char *data;

    dbi::AbstractStatement *st = DBI_STATEMENT(self);
    try {
        VALUE row = rb_hash_new();
        VALUE attrs = rb_ary_new();
        std::vector<string> fields = st->fields();
        std::vector<int> types = st->types();
        for (c = 0; c < fields.size(); c++) {
            rb_ary_push(attrs, ID2SYM(rb_intern(fields[c].c_str())));
        }
        for (r = 0; r < st->rows(); r++) {
            for (c = 0; c < st->columns(); c++) {
                data = (const char*)st->fetchValue(r,c, &len);
                if (data)
                    rb_hash_aset(row, rb_ary_entry(attrs, c), rb_field_typecast(types[c], data, len));
                else
                    rb_hash_aset(row, rb_ary_entry(attrs, c), Qnil);
            }
            rb_yield(row);
        }
    } catch EXCEPTION("Statment#each");
    return Qnil;
}

VALUE rb_statement_fetchrow(VALUE self) {
    const char *data;
    unsigned int r, c;
    unsigned long len;
    VALUE row = Qnil;
    dbi::AbstractStatement *st = DBI_STATEMENT(self);
    try {
        r = st->currentRow();
        if (r < st->rows()) {
            row = rb_ary_new();
            for (c = 0; c < st->columns(); c++) {
                data = (const char*)st->fetchValue(r, c, &len);
                rb_ary_push(row, data ? rb_str_new(data, len) : Qnil);
            }
            st->advanceRow();
        }
    } catch EXCEPTION("Statement#fetchrow");

    return row;
}

VALUE rb_statement_rewind(VALUE self) {
    dbi::AbstractStatement *st = DBI_STATEMENT(self);
    try { st->rewind(); } catch EXCEPTION("Statement#rewind");
    return Qnil;
}

VALUE rb_dbi_trace(int argc, VALUE *argv, VALUE self) {
    // by default log all messages to stderr.
    int fd = 2;
    rb_io_t *fptr;
    VALUE flag, io;

    rb_scan_args(argc, argv, "11", &flag, &io);

    if (TYPE(flag) != T_TRUE && TYPE(flag) != T_FALSE)
        rb_raise(eArgumentError, "DBI#trace expects a boolean flag, got %s", CSTRING(flag));

    if (!NIL_P(io)) {
        GetOpenFile(rb_convert_type(io, T_FILE, "IO", "to_io"), fptr);
        fd = fptr->fd;
    }

    dbi::trace(flag == Qtrue ? true : false, fd);
}

VALUE rb_handle_dup(VALUE self) {
    rb_raise(eRuntimeError, "Unable to Handle#dup or Handle#clone.");
}

VALUE rb_statement_dup(VALUE self) {
    rb_raise(eRuntimeError, "Unable to Statement#dup or Statement#clone.");
}

static void free_request(dbi::Request *self) {
    if(self) delete self;
}

VALUE rb_request_alloc(VALUE klass) {
    dbi::Request *r = 0;
    return Data_Wrap_Struct(klass, NULL, free_request, r);
}

static void free_cpool(dbi::ConnectionPool *self) {
    if (self) delete self;
}

VALUE rb_cpool_alloc(VALUE klass) {
    dbi::ConnectionPool *c = 0;
    return Data_Wrap_Struct(klass, NULL, free_cpool, c);
}

VALUE rb_cpool_init(VALUE self, VALUE n, VALUE opts) {
    VALUE db       = rb_hash_aref(opts, ID2SYM(rb_intern("db")));
    VALUE host     = rb_hash_aref(opts, ID2SYM(rb_intern("host")));
    VALUE port     = rb_hash_aref(opts, ID2SYM(rb_intern("port")));
    VALUE user     = rb_hash_aref(opts, ID2SYM(rb_intern("user")));
    VALUE driver   = rb_hash_aref(opts, ID2SYM(rb_intern("driver")));
    VALUE password = rb_hash_aref(opts, ID2SYM(rb_intern("password")));

    if (NIL_P(db)) rb_raise(eArgumentError, "ConnectionPool#new called without :db");
    if (NIL_P(user)) rb_raise(eArgumentError, "ConnectionPool#new called without :user");
    if (NIL_P(driver)) rb_raise(eArgumentError, "ConnectionPool#new called without :driver");

    host     = NIL_P(host)     ? rb_str_new2("") : host;
    port     = NIL_P(port)     ? rb_str_new2("") : port;
    password = NIL_P(password) ? rb_str_new2("") : password;

    if (NUM2INT(n) < 1) rb_raise(eArgumentError, "ConnectionPool#new called with invalid pool size.");

    try {
        DATA_PTR(self) = new dbi::ConnectionPool(
            n, CSTRING(driver), CSTRING(user), CSTRING(password), CSTRING(db), CSTRING(host), CSTRING(port)
        );
    } catch EXCEPTION("ConnectionPool#new");

    return Qnil;
}

void rb_cpool_callback(dbi::AbstractResultSet *rs) {
    VALUE callback = (VALUE)rs->context;
    rb_proc_call(callback, rb_ary_new3(1, Data_Wrap_Struct(cResultSet, 0, 0, rs)));
}

VALUE rb_cpool_execute(int argc, VALUE *argv, VALUE self) {
    dbi::ConnectionPool *cp = DBI_CPOOL(self);
    int n;
    VALUE sql;
    VALUE args;
    VALUE callback;
    VALUE request = Qnil;

    rb_scan_args(argc, argv, "1*&", &sql, &args, &callback);
    try {
        std::vector<dbi::Param> bind;
        for (n = 0; n < RARRAY_LEN(args); n++) {
            VALUE arg = rb_ary_entry(args, n);
            if (arg == Qnil)
                bind.push_back(dbi::PARAM(dbi::null()));
            else {
                arg = TO_STRING(arg);
                bind.push_back(dbi::PARAM_BINARY((unsigned char*)RSTRING_PTR(arg), RSTRING_LEN(arg)));
            }
        }
        // TODO GC mark callback.
        request = rb_request_alloc(cRequest);
        DATA_PTR(request) = cp->execute(CSTRING(sql), bind, rb_cpool_callback, (void*)callback);
    } catch EXCEPTION("ConnectionPool#execute");

    return request;
}

VALUE rb_request_socket(VALUE self) {
    dbi::Request *r = DBI_REQUEST(self);
    VALUE fd = Qnil;
    try {
        fd = INT2NUM(r->socket());
    } catch EXCEPTION("Request#socket");
    return fd;
}

VALUE rb_request_process(VALUE self) {
    VALUE rc = Qnil;
    dbi::Request *r = DBI_REQUEST(self);

    try {
        rc = r->process() ? Qtrue : Qfalse;
    } catch EXCEPTION("Request#process");

    return rc;
}

extern "C" {
    void Init_dbi(void) {
        struct tm tm;

        rb_require("bigdecimal");

        fNew             = rb_intern("new");
        fStringify       = rb_intern("to_s");
        eRuntimeError    = CONST_GET(rb_mKernel, "RuntimeError");
        eArgumentError   = CONST_GET(rb_mKernel, "ArgumentError");
        eStandardError   = CONST_GET(rb_mKernel, "StandardError");
        cBigDecimal      = CONST_GET(rb_mKernel, "BigDecimal");
        eConnectionError = rb_define_class("ConnectionError", eRuntimeError);

        mSwift           = rb_define_module("Swift");
        mDBI             = rb_define_module_under(mSwift, "DBI");
        cHandle          = rb_define_class_under(mDBI, "Handle", rb_cObject);
        cStatement       = rb_define_class_under(mDBI, "Statement", rb_cObject);
        cResultSet       = rb_define_class_under(mDBI, "ResultSet", cStatement);
        cPool            = rb_define_class_under(mDBI, "ConnectionPool", rb_cObject);
        cRequest         = rb_define_class_under(mDBI, "Request", rb_cObject);

        rb_define_module_function(mDBI, "init", RUBY_METHOD_FUNC(rb_dbi_init), 1);
        rb_define_module_function(mDBI, "trace", RUBY_METHOD_FUNC(rb_dbi_trace), -1);

        rb_define_alloc_func(cHandle, rb_handle_alloc);

        rb_define_method(cHandle, "initialize",  RUBY_METHOD_FUNC(rb_handle_init), 1);
        rb_define_method(cHandle, "prepare",     RUBY_METHOD_FUNC(rb_handle_prepare), 1);
        rb_define_method(cHandle, "execute",     RUBY_METHOD_FUNC(rb_handle_execute), -1);
        rb_define_method(cHandle, "begin",       RUBY_METHOD_FUNC(rb_handle_begin), -1);
        rb_define_method(cHandle, "commit",      RUBY_METHOD_FUNC(rb_handle_commit), -1);
        rb_define_method(cHandle, "rollback",    RUBY_METHOD_FUNC(rb_handle_rollback), -1);
        rb_define_method(cHandle, "transaction", RUBY_METHOD_FUNC(rb_handle_transaction), -1);
        rb_define_method(cHandle, "dup",         RUBY_METHOD_FUNC(rb_handle_dup),0);
        rb_define_method(cHandle, "clone",       RUBY_METHOD_FUNC(rb_handle_dup),0);

        rb_define_alloc_func(cStatement, rb_statement_alloc);

        rb_define_method(cStatement, "initialize",  RUBY_METHOD_FUNC(rb_statement_init), 2);
        rb_define_method(cStatement, "execute",     RUBY_METHOD_FUNC(rb_statement_execute), -1);
        rb_define_method(cStatement, "each",        RUBY_METHOD_FUNC(rb_statement_each), 0);
        rb_define_method(cStatement, "rows",        RUBY_METHOD_FUNC(rb_statement_rows), 0);
        rb_define_method(cStatement, "fetchrow",    RUBY_METHOD_FUNC(rb_statement_fetchrow), 0);
        rb_define_method(cStatement, "finish",      RUBY_METHOD_FUNC(rb_statement_finish), 0);
        rb_define_method(cStatement, "dup",         RUBY_METHOD_FUNC(rb_statement_dup), 0);
        rb_define_method(cStatement, "clone",       RUBY_METHOD_FUNC(rb_statement_dup), 0);
        rb_define_method(cStatement, "insert_id",   RUBY_METHOD_FUNC(rb_statement_insert_id), 0);
        rb_define_method(cStatement, "rewind",      RUBY_METHOD_FUNC(rb_statement_insert_id), 0);

        rb_include_module(cStatement, CONST_GET(rb_mKernel, "Enumerable"));


        rb_define_alloc_func(cPool, rb_cpool_alloc);

        rb_define_method(cPool, "initialize",  RUBY_METHOD_FUNC(rb_cpool_init), 2);
        rb_define_method(cPool, "execute",     RUBY_METHOD_FUNC(rb_cpool_execute), -1);

        rb_define_alloc_func(cRequest, rb_request_alloc);

        rb_define_method(cRequest, "socket",      RUBY_METHOD_FUNC(rb_request_socket), 0);
        rb_define_method(cRequest, "process",     RUBY_METHOD_FUNC(rb_request_process), 0);

        rb_define_method(cResultSet, "execute", RUBY_METHOD_FUNC(Qnil), 0);

        memset(&tm, 0, sizeof(struct tm));
        strptime("1970-01-01 00:00:00", "%F %T", &tm);
        tzoffset = mktime(&tm) * -1;
    }
}
