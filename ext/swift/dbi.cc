#include <dbic++.h>
#include <ruby/ruby.h>
#include <ruby/io.h>

#define CONST_GET(scope, constant) rb_const_get(scope, rb_intern(constant))

static VALUE mSwift;
static VALUE mDBI;
static VALUE cHandle;
static VALUE cStatement;
static VALUE eRuntimeError;
static VALUE eArgumentError;
static VALUE eStandardError;
static VALUE fStringify;

char errstr[8192];

#define CSTRING(v) RSTRING_PTR(TYPE(v) == T_STRING ? v : rb_funcall(v, fStringify, 0))
#define EXCEPTION(type) (const std::exception &e) { \
    snprintf(errstr, 4096, "%s", e.what()); \
    rb_raise(eRuntimeError, "%s Error: %s", type, errstr); \
}

static VALUE rb_statement_each(VALUE self);

static dbi::Handle* DBI_HANDLE(VALUE self) {
    dbi::Handle *h;
    Data_Get_Struct(self, dbi::Handle, h);
    return h;
}

static dbi::Statement* DBI_STATEMENT(VALUE self) {
    dbi::Statement *st;
    Data_Get_Struct(self, dbi::Statement, st);
    return st;
}

static void free_connection(dbi::Handle *self) {
    delete self;
}

static void free_statement(dbi::Statement *self) {
    delete self;
}

VALUE rb_dbi_init(VALUE self, VALUE path) {
    try { dbi::dbiInitialize(CSTRING(path)); } catch EXCEPTION("Invalid Driver");
}

void static inline rb_extract_bind_params(int argc, VALUE* argv, std::vector<dbi::Param> &bind) {
    for (int i = 0; i < argc; i++) bind.push_back(dbi::PARAM(CSTRING(argv[i])));
}

static VALUE rb_handle_new(VALUE klass, VALUE opts) {
    dbi::Handle *h;
    VALUE obj;

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
        h = new dbi::Handle(
            CSTRING(driver), CSTRING(user), CSTRING(password),
            CSTRING(db), CSTRING(host), CSTRING(port)
        );
    } catch EXCEPTION("Connection");

    obj = Data_Wrap_Struct(cHandle, NULL, free_connection, h);
    return obj;
}

static VALUE rb_handle_prepare(VALUE self, VALUE sql) {
    dbi::Handle *h = DBI_HANDLE(self);
    VALUE rv;
    try {
        dbi::Statement *st = new dbi::Statement(h, CSTRING(sql));
        rv = Data_Wrap_Struct(cStatement, NULL, free_statement, st);
    } catch EXCEPTION("Runtime");
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
            rb_extract_bind_params(argc, argv+1, bind);
            dbi::Statement st = h->prepare(CSTRING(argv[0]));
            rows = st.execute(bind);
        }
    } catch EXCEPTION("Runtime");
    return INT2NUM(rows);
}

VALUE rb_handle_begin(int argc, VALUE *argv, VALUE self) {
    dbi::Handle *h = DBI_HANDLE(self);
    VALUE save;
    rb_scan_args(argc, argv, "01", &save);
    try { NIL_P(save) ? h->begin() : h->begin(CSTRING(save)); } catch EXCEPTION("Runtime");
}

VALUE rb_handle_commit(int argc, VALUE *argv, VALUE self) {
    dbi::Handle *h = DBI_HANDLE(self);
    VALUE save;
    rb_scan_args(argc, argv, "01", &save);
    try { NIL_P(save) ? h->commit() : h->commit(CSTRING(save)); } catch EXCEPTION("Runtime");
}

VALUE rb_handle_rollback(int argc, VALUE *argv, VALUE self) {
    dbi::Handle *h = DBI_HANDLE(self);
    VALUE save_point;
    rb_scan_args(argc, argv, "01", &save_point);
    try { NIL_P(save_point) ? h->rollback() : h->rollback(CSTRING(save_point)); } catch EXCEPTION("Runtime");
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
    } catch EXCEPTION("Runtime");
}

VALUE rb_statement_new(VALUE klass, VALUE hl, VALUE sql) {
    dbi::Handle *h = DBI_HANDLE(hl);
    VALUE rv;

    if (NIL_P(hl)  || !h)
        rb_raise(eArgumentError, "Statement#new called without a Handle instance");
    if (NIL_P(sql))
        rb_raise(eArgumentError, "Statement#new called without a SQL command");

    try {
        dbi::Statement *st = new dbi::Statement(h, CSTRING(sql));
        rv = Data_Wrap_Struct(cStatement, NULL, free_statement, st);
    } catch EXCEPTION("Runtime");

    return rv;
}

VALUE rb_statement_execute(int argc, VALUE *argv, VALUE self) {
    dbi::Statement *st = DBI_STATEMENT(self);
    try {
        if (argc == 0) {
            st->execute();
        }
        else {
            dbi::ResultRow bind;
            rb_extract_bind_params(argc, argv, bind);
            st->execute(bind);
        }
    } catch EXCEPTION("Runtime");

    if (rb_block_given_p()) return rb_statement_each(self);
    return self;
}

VALUE rb_statement_finish(VALUE self) {
    dbi::Statement *st = DBI_STATEMENT(self);
    try {
        st->finish();
    } catch EXCEPTION("Runtime");
}

VALUE rb_statement_rows(VALUE self) {
    unsigned int rows;
    dbi::Statement *st = DBI_STATEMENT(self);
    try { rows = st->rows(); } catch EXCEPTION("Runtime");
    return INT2NUM(rows);
}

static VALUE rb_statement_each(VALUE self) {
    unsigned int r, c;
    unsigned long l;
    const char *vptr;
    dbi::Statement *st = DBI_STATEMENT(self);
    try {
        VALUE row = rb_hash_new();
        VALUE attrs = rb_ary_new();
        std::vector<string> fields = st->fields();
        for (c = 0; c < fields.size(); c++) {
            rb_ary_push(attrs, ID2SYM(rb_intern(fields[c].c_str())));
        }
        for (r = 0; r < st->rows(); r++) {
            for (c = 0; c < st->columns(); c++) {
                vptr = (const char*)st->fetchValue(r,c, &l);
                rb_hash_aset(row, rb_ary_entry(attrs, c), vptr ? rb_str_new(vptr, l) : Qnil);
            }
            rb_yield(row);
        }
    } catch EXCEPTION("Runtime");
}

VALUE rb_statement_fetchrow(VALUE self) {
    const char *vptr;
    unsigned int r, c;
    unsigned long l;
    VALUE row = Qnil;
    dbi::Statement *st = DBI_STATEMENT(self);
    try {
        r = st->currentRow();
        if (r < st->rows()) {
            row = rb_ary_new();
            for (c = 0; c < st->columns(); c++) {
                vptr = (const char*)st->fetchValue(r, c, &l);
                rb_ary_push(row, vptr ? rb_str_new(vptr, l) : Qnil);
            }
            st->advanceRow();
        }
    } catch EXCEPTION("Runtime");

    return row;
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

extern "C" {
    void Init_dbi(void) {

        fStringify     = rb_intern("to_s");
        eRuntimeError  = CONST_GET(rb_mKernel, "RuntimeError");
        eArgumentError = CONST_GET(rb_mKernel, "ArgumentError");
        eStandardError = CONST_GET(rb_mKernel, "StandardError");

        mSwift         = rb_define_module("Swift");
        mDBI           = rb_define_module_under(mSwift, "DBI");
        cHandle        = rb_define_class_under(mDBI, "Handle", rb_cObject);
        cStatement     = rb_define_class_under(mDBI, "Statement", rb_cObject);

        rb_define_module_function(mDBI, "init", RUBY_METHOD_FUNC(rb_dbi_init), 1);
        rb_define_module_function(mDBI, "trace", RUBY_METHOD_FUNC(rb_dbi_trace), -1);

        rb_define_singleton_method(cHandle, "new", RUBY_METHOD_FUNC(rb_handle_new), 1);

        rb_define_method(cHandle, "prepare",     RUBY_METHOD_FUNC(rb_handle_prepare), 1);
        rb_define_method(cHandle, "execute",     RUBY_METHOD_FUNC(rb_handle_execute), -1);
        rb_define_method(cHandle, "begin",       RUBY_METHOD_FUNC(rb_handle_begin), -1);
        rb_define_method(cHandle, "commit",      RUBY_METHOD_FUNC(rb_handle_commit), -1);
        rb_define_method(cHandle, "rollback",    RUBY_METHOD_FUNC(rb_handle_rollback), -1);
        rb_define_method(cHandle, "transaction", RUBY_METHOD_FUNC(rb_handle_transaction), -1);

        rb_define_singleton_method(cStatement, "new", RUBY_METHOD_FUNC(rb_statement_new), 2);

        rb_define_method(cStatement, "execute",  RUBY_METHOD_FUNC(rb_statement_execute), -1);
        rb_define_method(cStatement, "each",     RUBY_METHOD_FUNC(rb_statement_each), 0);
        rb_define_method(cStatement, "rows",     RUBY_METHOD_FUNC(rb_statement_rows), 0);
        rb_define_method(cStatement, "fetchrow", RUBY_METHOD_FUNC(rb_statement_fetchrow), 0);
        rb_define_method(cStatement, "finish",   RUBY_METHOD_FUNC(rb_statement_finish), 0);

        rb_include_module(cStatement, CONST_GET(rb_mKernel, "Enumerable"));
    }
}
