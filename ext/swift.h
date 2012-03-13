#ifndef SWIFT_H
#define SWIFT_H

#include <dbic++.h>
#include <ruby/ruby.h>
#include <ruby/io.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>

#define CONST_GET(scope, constant) rb_funcall(scope, rb_intern("const_get"), 1, rb_str_new2(constant))
#define TO_S(v)                    rb_funcall(v, rb_intern("to_s"), 0)
#define CSTRING(v)                 RSTRING_PTR(TO_S(v))
#define RUBY_STATIC_FUNC(func)     ((int (*)(ANYARGS))func)

extern VALUE eSwiftError;
extern VALUE eSwiftArgumentError;
extern VALUE eSwiftRuntimeError;
extern VALUE eSwiftConnectionError;

#define CATCH_DBI_EXCEPTIONS() \
  catch (dbi::ConnectionError &error) { \
    rb_raise(eSwiftConnectionError, "%s", error.what()); \
  } \
  catch (dbi::Error &error) { \
    rb_raise(eSwiftRuntimeError, "%s", error.what()); \
  } \
  catch (std::bad_alloc &error) { \
    rb_raise(rb_eNoMemError, "%s", error.what()); \
  } \
  catch (std::exception &error) { \
    rb_raise(rb_eRuntimeError, "%s", error.what()); \
  }


// works without a controlling tty, getlogin() will fail when process is daemonized.
inline VALUE current_user() {
  struct passwd *ptr = getpwuid(getuid());
  return ptr ? rb_str_new2(ptr->pw_name) : rb_str_new2("root");
}

#include "adapter.h"
#include "adapter_io.h"
#include "query.h"
#include "result.h"
#include "statement.h"
#include "attribute.h"
#include "datetime.h"

#undef SIZET2NUM
#ifdef HAVE_LONG_LONG
  #define SIZET2NUM(x) ULL2NUM(x)
  #define DAYMICROSECS 86400000000LL
#else
  #define SIZET2NUM(x) ULONG2NUM(x)
  #define DAYMICROSECS 86400000000L
#endif

#endif
