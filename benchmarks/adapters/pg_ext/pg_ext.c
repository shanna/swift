#include <ruby/ruby.h>
#include <ruby/io.h>
#include <stdint.h>
#include <time.h>
#include <libpq-fe.h>
#include <libpq/libpq-fs.h>

#define CONST_GET(scope, constant) rb_funcall(scope, rb_intern("const_get"), 1, rb_str_new2(constant))

/*
    Extracted from swift gem.

    1. This speeds up pg when you need typecasting and the ability to whip through results quickly.
    2. Adds PGresult#each and mixes in enumerable.

*/

ID fnew;
VALUE cStringIO, cBigDecimal;

int64_t client_tzoffset(int64_t local, int isdst) {
  struct tm tm;
  gmtime_r((const time_t*)&local, &tm);
  return (int64_t)(local + (isdst ? 3600 : 0) - mktime(&tm));
}

VALUE typecast_timestamp(const char *data, uint64_t len) {
  struct tm tm;
  int64_t epoch, adjust, offset;

  char tzsign = 0;
  int tzhour  = 0, tzmin = 0;
  long double sec_fraction = 0;

  memset(&tm, 0, sizeof(struct tm));
  if (strchr(data, '.')) {
    sscanf(data, "%04d-%02d-%02d %02d:%02d:%02d%Lf%c%02d:%02d",
      &tm.tm_year, &tm.tm_mon, &tm.tm_mday, &tm.tm_hour, &tm.tm_min, &tm.tm_sec, &sec_fraction,
      &tzsign, &tzhour, &tzmin);
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

    return rb_time_new(epoch+adjust-offset, (uint64_t)(sec_fraction*1000000L));
  }

  return rb_str_new(data, len);
}

VALUE typecast_date(const char *data, uint64_t len) {
  return rb_funcall(typecast_timestamp(data, len), rb_intern("to_date"), 0);
}

inline VALUE typecast(const char* data, uint64_t len, int pgtype) {
  size_t bytea_len;
  unsigned char* bytea;
  VALUE rv;

  switch(pgtype) {
    case 16:
      return *data == 't' ? Qtrue : Qfalse;
    case 17:
      bytea = PQunescapeBytea(data, &bytea_len);
      rv = rb_funcall(cStringIO, fnew, 1, rb_str_new(bytea, bytea_len));
      PQfreemem(bytea);
      return rv;
    case 20:
    case 21:
    case 22:
    case 23:
    case 26:
      return rb_cstr2inum(data, 10);
    case 700:
    case 701:
    case 790:
      return rb_float_new(atof(data));
    case 1700:
      return rb_funcall(cBigDecimal, fnew, 1, rb_str_new(data, len));
    case 1082:
      return typecast_date(data, len);
    case 1114:
    case 1184:
      return typecast_timestamp(data, len);
    default:
      return rb_str_new(data, len);
  }
}

VALUE result_each(VALUE self) {
    int r, c, rows, cols, *types;
    PGresult *res;
    Data_Get_Struct(self, PGresult, res);

    VALUE fields = rb_ary_new();
    rows  = PQntuples(res);
    cols  = PQnfields(res);
    types = (int*)malloc(sizeof(int)*cols);
    for (c = 0; c < cols; c++) {
        rb_ary_push(fields, ID2SYM(rb_intern(PQfname(res, c))));
        types[c] = PQftype(res, c);
    }

    for (r = 0; r < rows; r++) {
        VALUE tuple = rb_hash_new();
        for (c = 0; c < cols; c++) {
            rb_hash_aset(tuple, rb_ary_entry(fields, c),
                PQgetisnull(res, r, c) ? Qnil : typecast(PQgetvalue(res, r, c), PQgetlength(res, r, c), types[c]));
        }
        rb_yield(tuple);
    }

    free(types);
    return Qnil;
}

void Init_pg_ext() {
  rb_require("pg");
  rb_require("date");
  rb_require("stringio");
  rb_require("bigdecimal");

  fnew        = rb_intern("new");
  cStringIO   = CONST_GET(rb_mKernel, "StringIO");
  cBigDecimal = CONST_GET(rb_mKernel, "BigDecimal");

  VALUE cPGresult = rb_define_class("PGresult", rb_cObject);
  rb_include_module(cPGresult, CONST_GET(rb_mKernel, "Enumerable"));
  rb_define_method(cPGresult, "each", RUBY_METHOD_FUNC(result_each), 0);
}
