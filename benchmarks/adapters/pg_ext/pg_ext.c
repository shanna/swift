#include <ruby/ruby.h>
#include <ruby/io.h>
#include <stdint.h>
#include <time.h>

// Calculates local offset at a given time, including dst.
int64_t client_tzoffset(int64_t local, int isdst) {
  struct tm tm;
  gmtime_r((const time_t*)&local, &tm);
  // TODO: This won't work in Lord Howe Island, Australia which uses half hour shift.
  return (int64_t)(local + (isdst ? 3600 : 0) - mktime(&tm));
}

VALUE typecast_timestamp(VALUE self, VALUE str) {
  struct tm tm;
  int64_t epoch, adjust, offset;

  char tzsign = 0, *data = RSTRING_PTR(str);
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

  return str;
}

VALUE typecast_date(VALUE self, VALUE str) {
  return rb_funcall(typecast_timestamp(self, str), rb_intern("to_date"), 0);
}

void Init_pg_ext() {
  rb_require("pg");
  rb_require("date");

  VALUE cPGconn = rb_define_class("PGconn", rb_cObject);

  rb_define_module_function(cPGconn, "typecast_date",      RUBY_METHOD_FUNC(typecast_date),      1);
  rb_define_module_function(cPGconn, "typecast_timestamp", RUBY_METHOD_FUNC(typecast_timestamp), 1);
}

