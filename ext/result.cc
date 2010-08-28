#include "result.h"
    .scheme

VALUE cSwiftResult;
VALUE cDateTime;
VALUE cStringIO;
VALUE cBigDecimal;

VALUE fNew, fNewBang;

uint64_t epoch_ajd_n, epoch_ajd_d;
VALUE day_secs;

void result_free(dbi::AbstractResultSet *result) {
  if (result) {
    result->cleanup();
    delete result;
  }
}

VALUE result_alloc(VALUE klass) {
  dbi::AbstractResultSet *result = 0;
  return Data_Wrap_Struct(klass, 0, result_free, result);
}

// TODO:
static VALUE result_clone(VALUE self) {
  rb_raise(eSwiftRuntimeError, "clone is not allowed.");
}

// TODO:
static VALUE result_dup(VALUE self) {
  rb_raise(eSwiftRuntimeError, "dup is not allowed.");
}

VALUE result_each(VALUE self) {
  ulong length;
  const char *data;

  dbi::AbstractResultSet *result = result_handle(self);
  VALUE scheme = rb_iv_get(self, "@scheme");

  try {
    VALUE fields                      = rb_ary_new();
    std::vector<string> result_fields = result->fields();
    std::vector<int>    result_types  = result->types();
    for (uint i = 0; i < result_fields.size(); i++) {
      rb_ary_push(fields, ID2SYM(rb_intern(result_fields[i].c_str())));
    }

    result->seek(0);
    for (uint row = 0; row < result->rows(); row++) {
      VALUE tuple = rb_hash_new();
      for (uint column = 0; column < result->columns(); column++) {
        data = (const char*)result->read(row, column, &length);
        if (data) {
          rb_hash_aset(
            tuple,
            rb_ary_entry(fields, column),
            typecast_field(result_types[column], data, length)
          );
        }
        else {
          rb_hash_aset(tuple, rb_ary_entry(fields, column), Qnil);
        }
      } // column loop
      NIL_P(scheme) ? rb_yield(tuple) : rb_yield(rb_funcall(scheme, rb_intern("load"), 1, tuple));
    } // row loop
  }
  CATCH_DBI_EXCEPTIONS();

  return Qnil;
}

dbi::AbstractResultSet* result_handle(VALUE self) {
  dbi::AbstractResultSet *result;
  Data_Get_Struct(self, dbi::AbstractResultSet, result);
  if (!result) rb_raise(eSwiftRuntimeError, "Invalid object, did you forget to call #super?");

  return result;
}

static VALUE result_finish(VALUE self) {
  dbi::AbstractResultSet *result = result_handle(self);
  try {
    result->finish();
  }
  CATCH_DBI_EXCEPTIONS();
}

// Calculates local offset at a given time, including dst.
size_t client_tzoffset(struct tm *given) {
  struct tm tm;
  uint64_t utc, local, dst = 0;
  memcpy(&tm, given, sizeof(tm));

  tm.tm_isdst = -1;
  local       = mktime(&tm);
  dst         = tm.tm_isdst ? 3600 : 0;
  gmtime_r((const time_t*)&local, &tm);
  utc = mktime(&tm);
  return local+dst-utc;
}

VALUE typecast_datetime(const char *data, ulong len) {
  struct tm tm;
  uint64_t epoch, adjust, offset, tzoffset;

  double usec = 0;
  char tzsign = 0;
  int tzhour  = 0, tzmin = 0;

  memset(&tm, 0, sizeof(struct tm));
  if (strchr(data, '.')) {
    sscanf(data, "%04d-%02d-%02d %02d:%02d:%02d%lf%c%02d:%02d",
      &tm.tm_year, &tm.tm_mon, &tm.tm_mday, &tm.tm_hour, &tm.tm_min, &tm.tm_sec,
      &usec, &tzsign, &tzhour, &tzmin);
  }
  else {
    sscanf(data, "%04d-%02d-%02d %02d:%02d:%02d%c%02d:%02d",
      &tm.tm_year, &tm.tm_mon, &tm.tm_mday, &tm.tm_hour, &tm.tm_min, &tm.tm_sec,
      &tzsign, &tzhour, &tzmin);
  }
  tm.tm_year  -= 1900;
  tm.tm_mon   -= 1;
  tm.tm_isdst = -1;
  if (tm.tm_mday > 0) {
    epoch  = mktime(&tm);
    adjust = client_tzoffset(&tm);
    offset = adjust;
    if (tzsign == '+' || tzsign == '-') {
      offset = tzsign == '+'
        ? (time_t)tzhour *  3600 + (time_t)tzmin *  60
        : (time_t)tzhour * -3600 + (time_t)tzmin * -60;
    }
    VALUE ajd = rb_rational_new(ULONG2NUM(epoch_ajd_n + epoch + adjust - offset), day_secs);
    return rb_funcall(cDateTime, fNewBang, 3, ajd, rb_rational_new(INT2FIX(offset), day_secs), INT2NUM(2299161));
  }

  // TODO: throw a warning ?
  return rb_str_new(data, len);
}

VALUE typecast_field(int type, const char *data, ulong length) {
  switch(type) {
    case DBI_TYPE_BOOLEAN:
      return strcmp(data, "t") == 0 || strcmp(data, "1") == 0 ? Qtrue : Qfalse;
    case DBI_TYPE_INT:
      return rb_cstr2inum(data, 10);
    case DBI_TYPE_BLOB:
      return rb_funcall(cStringIO, fNew, 1, rb_str_new(data, length));
    case DBI_TYPE_TEXT:
      return rb_enc_str_new(data, length, rb_utf8_encoding());
    case DBI_TYPE_TIME:
      return typecast_datetime(data, length);
    case DBI_TYPE_NUMERIC:
      return rb_funcall(cBigDecimal, fNew, 1, rb_str_new2(data));
    case DBI_TYPE_FLOAT:
      return rb_float_new(atof(data));
  }
}

VALUE result_insert_id(VALUE self) {
  dbi::AbstractResultSet *result = result_handle(self);
  try {
    return ULONG2NUM(result->lastInsertID());
  }
  CATCH_DBI_EXCEPTIONS();
  return Qnil;
}

VALUE result_rows(VALUE self) {
  dbi::AbstractResultSet *result = result_handle(self);
  try {
    return ULONG2NUM(result->rows());
  }
  CATCH_DBI_EXCEPTIONS();
}

VALUE result_columns(VALUE self) {
  dbi::AbstractResultSet *result = result_handle(self);
  try {
    return ULONG2NUM(result->columns());
  }
  CATCH_DBI_EXCEPTIONS();
}

VALUE result_fields(VALUE self) {
  dbi::AbstractResultSet *result = result_handle(self);
  try {
    std::vector<string> result_fields = result->fields();
    VALUE fields = rb_ary_new();
    for (int i = 0; i < result_fields.size(); i++)
      rb_ary_push(fields, rb_str_new2(result_fields[i].c_str()));
    return fields;
  }
  CATCH_DBI_EXCEPTIONS();
}

void init_swift_result() {
  rb_require("bigdecimal");
  rb_require("stringio");
  rb_require("date");

  VALUE mSwift = rb_define_module("Swift");
  cSwiftResult = rb_define_class_under(mSwift, "Result", rb_cObject);
  cDateTime    = CONST_GET(rb_mKernel, "DateTime");
  cStringIO    = CONST_GET(rb_mKernel, "StringIO");
  cBigDecimal  = CONST_GET(rb_mKernel, "BigDecimal");

  fNew         = rb_intern("new");
  fNewBang     = rb_intern("new!");

  rb_define_alloc_func(cSwiftResult, result_alloc);
  rb_include_module(cSwiftResult, CONST_GET(rb_mKernel, "Enumerable"));

  rb_define_method(cSwiftResult, "clone",      RUBY_METHOD_FUNC(result_clone),     0);
  rb_define_method(cSwiftResult, "dup",        RUBY_METHOD_FUNC(result_dup),       0);
  rb_define_method(cSwiftResult, "each",       RUBY_METHOD_FUNC(result_each),      0);
  rb_define_method(cSwiftResult, "finish",     RUBY_METHOD_FUNC(result_finish),    0);
  rb_define_method(cSwiftResult, "insert_id",  RUBY_METHOD_FUNC(result_insert_id), 0);
  rb_define_method(cSwiftResult, "rows",       RUBY_METHOD_FUNC(result_rows),      0);
  rb_define_method(cSwiftResult, "columns",    RUBY_METHOD_FUNC(result_columns),   0);
  rb_define_method(cSwiftResult, "fields",     RUBY_METHOD_FUNC(result_fields),    0);

  // setup variables need for typecast_datetime
  epoch_ajd_d = 86400;
  epoch_ajd_n = (2440587L*2+1) * 43200L;
  day_secs    = INT2FIX(86400);
}

