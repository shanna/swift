#include "result.h"
#include "datetime.h"
#include <math.h>

#define date_parse(klass, data,len) rb_funcall(datetime_parse(klass, data, len), fto_date, 0)

VALUE cBigDecimal, cStringIO, cSwiftResult;
ID fnew, fload, fto_date;

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

// NOTE clone and dup cannot be allowed since the underlying c++ object needs to be cloned, which
//      frankly is too much work :)
static VALUE result_clone(VALUE self) {
  rb_raise(eSwiftRuntimeError, "clone is not allowed.");
}

static VALUE result_dup(VALUE self) {
  rb_raise(eSwiftRuntimeError, "dup is not allowed.");
}

VALUE result_each(VALUE self) {
  uint64_t length;
  const char *data;

  dbi::AbstractResult *result = result_handle(self);
  VALUE scheme   = rb_iv_get(self, "@scheme");

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
            typecast_field(result_types[column], data, length)
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

VALUE typecast_field(int type, const char *data, uint64_t length) {
  switch(type) {
    case DBI_TYPE_BOOLEAN:
      return (data && (data[0] =='t' || data[0] == '1')) ? Qtrue : Qfalse;
    case DBI_TYPE_INT:
      return rb_cstr2inum(data, 10);
    case DBI_TYPE_BLOB:
      return rb_funcall(cStringIO, fnew, 1, rb_str_new(data, length));
    case DBI_TYPE_TIMESTAMP:
      return datetime_parse(cSwiftDateTime, data, length);
    case DBI_TYPE_DATE:
      return date_parse(cSwiftDateTime, data, length);
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

VALUE result_field_types(VALUE self) {
  dbi::AbstractResult *result   = result_handle(self);
  std::vector<int> result_types = result->types();

  VALUE types = rb_ary_new();
  for (std::vector<int>::iterator it = result_types.begin(); it != result_types.end(); it++) {
    switch(*it) {
      case DBI_TYPE_BOOLEAN:
        rb_ary_push(types, rb_str_new2("boolean"));
        break;
      case DBI_TYPE_INT:
        rb_ary_push(types, rb_str_new2("integer"));
        break;
      case DBI_TYPE_BLOB:
        rb_ary_push(types, rb_str_new2("blob"));
        break;
      case DBI_TYPE_TIMESTAMP:
        rb_ary_push(types, rb_str_new2("timestamp"));
        break;
      case DBI_TYPE_DATE:
        rb_ary_push(types, rb_str_new2("date"));
        break;
      case DBI_TYPE_NUMERIC:
        rb_ary_push(types, rb_str_new2("numeric"));
        break;
      case DBI_TYPE_FLOAT:
        rb_ary_push(types, rb_str_new2("float"));
        break;
      case DBI_TYPE_TIME:
        rb_ary_push(types, rb_str_new2("time"));
        break;
      default:
        rb_ary_push(types, rb_str_new2("text"));
    }
  }

  return types;
}

VALUE result_retrieve(VALUE self) {
  dbi::AbstractResult *result = result_handle(self);
  try {
    while (result->consumeResult());
    result->prepareResult();
  }
  CATCH_DBI_EXCEPTIONS();
  return true;
}

void init_swift_result() {
  rb_require("bigdecimal");
  rb_require("stringio");

  VALUE mSwift = rb_define_module("Swift");
  cSwiftResult = rb_define_class_under(mSwift, "Result", rb_cObject);
  cStringIO    = CONST_GET(rb_mKernel, "StringIO");
  cBigDecimal  = CONST_GET(rb_mKernel, "BigDecimal");

  fto_date     = rb_intern("to_date");
  fnew         = rb_intern("new");
  fload        = rb_intern("load");

  rb_define_alloc_func(cSwiftResult, result_alloc);
  rb_include_module(cSwiftResult, CONST_GET(rb_mKernel, "Enumerable"));

  rb_define_method(cSwiftResult, "retrieve",    RUBY_METHOD_FUNC(result_retrieve),    0);
  rb_define_method(cSwiftResult, "clone",       RUBY_METHOD_FUNC(result_clone),       0);
  rb_define_method(cSwiftResult, "dup",         RUBY_METHOD_FUNC(result_dup),         0);
  rb_define_method(cSwiftResult, "each",        RUBY_METHOD_FUNC(result_each),        0);
  rb_define_method(cSwiftResult, "insert_id",   RUBY_METHOD_FUNC(result_insert_id),   0);
  rb_define_method(cSwiftResult, "rows",        RUBY_METHOD_FUNC(result_rows),        0);
  rb_define_method(cSwiftResult, "columns",     RUBY_METHOD_FUNC(result_columns),     0);
  rb_define_method(cSwiftResult, "fields",      RUBY_METHOD_FUNC(result_fields),      0);
  rb_define_method(cSwiftResult, "field_types", RUBY_METHOD_FUNC(result_field_types), 0);
}

