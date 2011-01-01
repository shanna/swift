#include "result.h"
#include <math.h>

VALUE cBigDecimal;
VALUE cStringIO;
VALUE cSwiftResult;

ID fnew, fto_date, fload;

void result_mark(ResultWrapper *handle) {
  if (handle)
    rb_gc_mark(handle->adapter);
}

void result_free(ResultWrapper *handle) {
  if (handle) {
    if (handle->free) delete handle->result;
    delete handle;
  }
}

VALUE result_alloc(VALUE klass) {
  ResultWrapper *handle = 0;
  return Data_Wrap_Struct(klass, result_mark, result_free, handle);
}

VALUE result_wrap_handle(VALUE klass, VALUE adapter, dbi::AbstractResult *result, bool free) {
  ResultWrapper *handle = new ResultWrapper;
  handle->result  = result;
  handle->adapter = adapter;
  handle->free    = free;

  VALUE obj = Data_Wrap_Struct(klass, result_mark, result_free, handle);
  if (!NIL_P(adapter))
    rb_iv_set(obj, "@timezone", rb_iv_get(adapter, "@timezone"));

  return obj;
}

dbi::AbstractResult* result_handle(VALUE self) {
  ResultWrapper *handle;
  Data_Get_Struct(self, ResultWrapper, handle);
  if (!handle) rb_raise(eSwiftRuntimeError, "Invalid object, did you forget to call #super?");

  return handle->result;
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
  uint64_t length;
  const char *data, *tzstring;

  dbi::AbstractResult *result = result_handle(self);
  VALUE scheme   = rb_iv_get(self, "@scheme");
  VALUE timezone = rb_iv_get(self, "@timezone");

  tzstring = NIL_P(timezone) ? 0 : CSTRING(timezone);

  try {
    std::vector<string> result_fields = result->fields();
    std::vector<int>    result_types  = result->types();
    std::vector<VALUE>  fields;
    for (uint32_t i = 0; i < result_fields.size(); i++)
      fields.push_back(ID2SYM(rb_intern(result_fields[i].c_str())));

    result->seek(0);
    for (uint32_t row = 0; row < result->rows(); row++) {
      VALUE tuple = rb_hash_new();
      for (uint32_t column = 0; column < result->columns(); column++) {
        data = (const char*)result->read(row, column, &length);
        if (data) {
          rb_hash_aset(
            tuple,
            fields[column],
            typecast_field(result_types[column], data, length, tzstring)
          );
        }
        else {
          rb_hash_aset(tuple, fields[column], Qnil);
        }
      } // column loop
      NIL_P(scheme) ? rb_yield(tuple) : rb_yield(rb_funcall(scheme, fload, 1, tuple));
    } // row loop
  }
  CATCH_DBI_EXCEPTIONS();

  return Qnil;
}

// Calculates local offset at a given time, including dst.
int64_t client_tzoffset(int64_t local, int isdst) {
  struct tm tm;
  gmtime_r((const time_t*)&local, &tm);
  // TODO: This won't work in Lord Howe Island, Australia which uses half hour shift.
  return (int64_t)(local + (isdst ? 3600 : 0) - mktime(&tm));
}

// Calculates server offset at a given time, including dst.
int64_t server_tzoffset(struct tm* tm, const char *zone) {
  uint64_t local;
  int64_t  offset;
  char buffer[512];
  char *old, saved[512];
  struct tm tm_copy;

  // save current zone setting.
  if ((old = getenv("TZ"))) {
    strncpy(saved, old, 512);
    saved[511] = 0;
  }

  // setup.
  snprintf(buffer, 512, ":%s", zone);
  setenv("TZ", buffer, 1);
  tzset();

  // pretend we're on server timezone and calculate offset.
  memcpy(&tm_copy, tm, sizeof(struct tm));
  tm_copy.tm_isdst = -1;
  local  = mktime(&tm_copy);
  offset = client_tzoffset(local, tm_copy.tm_isdst);

  // reset timezone to what it was before.
  old ? setenv("TZ", saved, 1) : unsetenv("TZ");
  tzset();

  return offset;
}

VALUE typecast_timestamp(const char *data, uint64_t len, const char *zone) {
  struct   tm tm;
  int64_t  epoch, adjust, offset;
  uint64_t usec   = 0;
  char     tzsign = 0, subsec[32];
  int      tzhour = 0, tzmin = 0;

  memset(&tm, 0, sizeof(struct tm));
  // Based on github.com/jeremyevans/sequel_pg. atoll & pow seem to be tad faster than sscanf %Lf
  // NOTE: Reading subsec as string means malformed subsec > 32 digits could break this.
  if (strchr(data, '.')) {
    sscanf(data, "%04d-%02d-%02d %02d:%02d:%02d.%s%c%02d:%02d",
      &tm.tm_year, &tm.tm_mon, &tm.tm_mday, &tm.tm_hour, &tm.tm_min, &tm.tm_sec, subsec,
      &tzsign, &tzhour, &tzmin);
      usec = atoll(subsec)*(uint64_t)pow(10, 6 - strlen(subsec));
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
    adjust = client_tzoffset(epoch, tm.tm_isdst);
    offset = adjust;

    if (tzsign) {
      offset = tzsign == '+'
        ? (time_t)tzhour *  3600 + (time_t)tzmin *  60
        : (time_t)tzhour * -3600 + (time_t)tzmin * -60;
    }
    else if (zone) {
      if (strncasecmp(zone, "UTC", 3) == 0 || strncasecmp(zone, "GMT", 3) == 0)
        offset = 0;
      else if (strcmp(zone, "+00:00") == 0 || strcmp(zone, "+0000") == 0)
        offset = 0;
      else if (sscanf(zone, "%c%02d%02d",  &tzsign, &tzhour, &tzmin) == 3)
        offset = tzsign == '+'
          ? (time_t)tzhour *  3600 + (time_t)tzmin *  60
          : (time_t)tzhour * -3600 + (time_t)tzmin * -60;
      else if (sscanf(zone, "%c%02d:%02d", &tzsign, &tzhour, &tzmin) >= 2)
        offset = tzsign == '+'
          ? (time_t)tzhour *  3600 + (time_t)tzmin *  60
          : (time_t)tzhour * -3600 + (time_t)tzmin * -60;
      else
        offset = server_tzoffset(&tm, zone);
    }

    return rb_time_new(epoch+adjust-offset, usec);
  }

  printf("WARNING: Unable to parse timestamp value '%s'\n", data);
  return rb_str_new(data, len);
}

#define typecast_date(data,len,tz)   rb_funcall(typecast_timestamp(data,len,tz), fto_date, 0)

/*
  This is my wish list below for rubycore - to be built into core ruby.
  1. Time class represents time - time zone invariant
  2. Date class represents a date - time zone invariant
  3. DateTime class represents a timestamp with full zoneinfo support.
*/

VALUE typecast_field(int type, const char *data, uint64_t length, const char* timezone) {
  switch(type) {
    case DBI_TYPE_BOOLEAN:
      return (data && (data[0] =='t' || data[0] == '1')) ? Qtrue : Qfalse;
    case DBI_TYPE_INT:
      return rb_cstr2inum(data, 10);
    case DBI_TYPE_BLOB:
      return rb_funcall(cStringIO, fnew, 1, rb_str_new(data, length));
    case DBI_TYPE_TIMESTAMP:
      return typecast_timestamp(data, length, timezone);
    case DBI_TYPE_DATE:
      return typecast_date(data, length, timezone);
    case DBI_TYPE_NUMERIC:
      return rb_funcall(cBigDecimal, fnew, 1, rb_str_new2(data));
    case DBI_TYPE_FLOAT:
      return rb_float_new(atof(data));

    // DBI_TYPE_TIME
    // DBI_TYPE_TEXT
    default:
      return rb_enc_str_new(data, length, rb_utf8_encoding());
  }
}

VALUE result_insert_id(VALUE self) {
  dbi::AbstractResult *result = result_handle(self);
  try {
    return SIZET2NUM(result->lastInsertID());
  }
  CATCH_DBI_EXCEPTIONS();
  return Qnil;
}

VALUE result_rows(VALUE self) {
  dbi::AbstractResult *result = result_handle(self);
  try {
    return SIZET2NUM(result->rows());
  }
  CATCH_DBI_EXCEPTIONS();
}

VALUE result_columns(VALUE self) {
  dbi::AbstractResult *result = result_handle(self);
  try {
    return SIZET2NUM(result->columns());
  }
  CATCH_DBI_EXCEPTIONS();
}

VALUE result_fields(VALUE self) {
  dbi::AbstractResult *result = result_handle(self);
  try {
    std::vector<string> result_fields = result->fields();
    VALUE fields = rb_ary_new();
    for (int i = 0; i < result_fields.size(); i++)
      rb_ary_push(fields, ID2SYM(rb_intern(result_fields[i].c_str())));
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
  cStringIO    = CONST_GET(rb_mKernel, "StringIO");
  cBigDecimal  = CONST_GET(rb_mKernel, "BigDecimal");

  fnew         = rb_intern("new");
  fto_date     = rb_intern("to_date");
  fload        = rb_intern("load");

  rb_define_alloc_func(cSwiftResult, result_alloc);
  rb_include_module(cSwiftResult, CONST_GET(rb_mKernel, "Enumerable"));

  rb_define_method(cSwiftResult, "clone",      RUBY_METHOD_FUNC(result_clone),     0);
  rb_define_method(cSwiftResult, "dup",        RUBY_METHOD_FUNC(result_dup),       0);
  rb_define_method(cSwiftResult, "each",       RUBY_METHOD_FUNC(result_each),      0);
  rb_define_method(cSwiftResult, "insert_id",  RUBY_METHOD_FUNC(result_insert_id), 0);
  rb_define_method(cSwiftResult, "rows",       RUBY_METHOD_FUNC(result_rows),      0);
  rb_define_method(cSwiftResult, "columns",    RUBY_METHOD_FUNC(result_columns),   0);
  rb_define_method(cSwiftResult, "fields",     RUBY_METHOD_FUNC(result_fields),    0);
}

