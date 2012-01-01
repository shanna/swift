#include "datetime.h"

VALUE cSwiftDateTime;
ID fcivil, fparse;

// NOTE: only parses '%F %T %z' format and falls back to the built-in DateTime#parse
VALUE datetime_parse(VALUE klass, const char *data, uint64_t size) {
  struct tm tm;
  size_t seconds_n, seconds_d = 1, precision;
  const char *ptr;
  char tzsign = 0, fraction[32];
  int  tzhour = 0, tzmin = 0, lastmatch = -1, offset = 0, idx;

  memset(&tm, 0, sizeof(struct tm));
  sscanf(data, "%04d-%02d-%02d %02d:%02d:%02d%n",
      &tm.tm_year, &tm.tm_mon, &tm.tm_mday, &tm.tm_hour, &tm.tm_min, &tm.tm_sec, &lastmatch);

  // fallback to default datetime parser, this is more expensive.
  if (tm.tm_mday == 0)
    return Qnil;

  seconds_n = tm.tm_sec;

  // parse millisecs if any -- tad faster than using %lf in sscanf above.
  if (lastmatch > 0 && lastmatch < size && *(data + lastmatch) == '.') {
      idx = 0;
      ptr = data + ++lastmatch;
      while (*ptr && isdigit(*ptr) && idx < 31) {
        lastmatch++;
        fraction[idx++] = *ptr++;
      }

      fraction[idx] = 0;

      precision = pow(10, idx);
      seconds_d = precision > 1000000 ? precision : 1000000;
      seconds_n = seconds_n * seconds_d + (seconds_d * (double)atoll(fraction)) / (double)precision;
  }

  // parse timezone offsets if any - matches +HH:MM +HH MM +HHMM
  if (lastmatch > 0 && lastmatch < size) {
    const char *ptr = data + lastmatch;
    while(*ptr && *ptr != '+' && *ptr != '-') ptr++;
    tzsign = *ptr++;
    if (*ptr && isdigit(*ptr)) {
      tzhour = *ptr++ - '0';
      if (*ptr && isdigit(*ptr)) tzhour = tzhour * 10 + *ptr++ - '0';
      while(*ptr && !isdigit(*ptr)) ptr++;
      if (*ptr) {
        tzmin = *ptr++ - '0';
        if (*ptr && isdigit(*ptr)) tzmin = tzmin * 10 + *ptr++ - '0';
      }
    }
  }

  if (tzsign) {
    offset = tzsign == '+'
      ? (time_t)tzhour *  3600 + (time_t)tzmin *  60
      : (time_t)tzhour * -3600 + (time_t)tzmin * -60;
  }

  return rb_funcall(klass, fcivil, 7,
    INT2FIX(tm.tm_year), INT2FIX(tm.tm_mon), INT2FIX(tm.tm_mday),
    INT2FIX(tm.tm_hour), INT2FIX(tm.tm_min), rb_rational_new(SIZET2NUM(seconds_n), SIZET2NUM(seconds_d)),
    offset == 0 ? INT2FIX(0) : rb_rational_new(INT2FIX(offset), INT2FIX(86400))
  );
}

VALUE rb_datetime_parse(VALUE self, VALUE string) {
  const char *data = CSTRING(string);
  int size = TYPE(string) == T_STRING ? RSTRING_LEN(string) : strlen(data);

  if (NIL_P(string))
    return Qnil;

  VALUE datetime = datetime_parse(self, data, size);
  return NIL_P(datetime) ? rb_call_super(1, &string) : datetime;
}

void init_swift_datetime() {
  rb_require("date");

  VALUE mSwift    = rb_define_module("Swift");
  VALUE cDateTime = CONST_GET(rb_mKernel, "DateTime");
  cSwiftDateTime  = rb_define_class_under(mSwift, "DateTime", cDateTime);
  fcivil          = rb_intern("civil");
  fparse          = rb_intern("parse");

  rb_define_singleton_method(cSwiftDateTime, "parse", RUBY_METHOD_FUNC(rb_datetime_parse), 1);
}
