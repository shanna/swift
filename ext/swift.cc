#include "swift.h"

static VALUE mSwift;

VALUE eSwiftError;
VALUE eSwiftArgumentError;
VALUE eSwiftRuntimeError;
VALUE eSwiftConnectionError;

VALUE rb_special_constant(VALUE self, VALUE obj) {
  return rb_special_const_p(obj) ? Qtrue : Qfalse;
}

VALUE swift_init(VALUE self, VALUE path) {
  try { dbi::dbiInitialize(CSTRING(path)); } CATCH_DBI_EXCEPTIONS();
  return Qtrue;
}

VALUE swift_trace(int argc, VALUE *argv, VALUE self) {
    VALUE flag, io;
    rb_io_t *fptr;
    int fd = 2; // defaults to stderr

    rb_scan_args(argc, argv, "11", &flag, &io);

    if (TYPE(flag) != T_TRUE && TYPE(flag) != T_FALSE)
        rb_raise(eSwiftArgumentError, "Swift#trace expects a boolean flag, got %s", CSTRING(flag));

    if (!NIL_P(io)) {
        GetOpenFile(rb_convert_type(io, T_FILE, "IO", "to_io"), fptr);
        fd = fptr->fd;
    }

    dbi::trace(flag == Qtrue ? true : false, fd);
    return flag;
}

VALUE atexit_gc(...) {
  rb_gc();
  return Qnil;
}

void atexit_caller(VALUE data) {
  rb_proc_call(data, rb_ary_new());
}

extern "C" {
  void Init_swift(void) {
    mSwift = rb_define_module("Swift");

    eSwiftError           = rb_define_class("SwiftError", CONST_GET(rb_mKernel, "StandardError"));
    eSwiftArgumentError   = rb_define_class("SwiftArgumentError",   eSwiftError);
    eSwiftRuntimeError    = rb_define_class("SwiftRuntimeError",    eSwiftError);
    eSwiftConnectionError = rb_define_class("SwiftConnectionError", eSwiftError);

    init_swift_adapter();
    init_swift_result();
    init_swift_statement();
    init_swift_request();
    init_swift_pool();

    rb_define_module_function(mSwift, "init",  RUBY_METHOD_FUNC(swift_init), 1);
    rb_define_module_function(mSwift, "trace", RUBY_METHOD_FUNC(swift_trace), -1);
    rb_define_module_function(mSwift, "special_constant?", RUBY_METHOD_FUNC(rb_special_constant), 1);

    // NOTE
    // Swift adapter and statement objects need to be deallocated or garbage collected in the reverse
    // allocation order. rb_gc() does that but gc at exit time seems to do it in allocation order which
    // stuffs up dbic++ destructors.
    rb_set_end_proc(atexit_caller, rb_proc_new(atexit_gc, mSwift));
  }
}

