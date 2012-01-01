#include "swift.h"

static VALUE mSwift;

VALUE eSwiftError;
VALUE eSwiftArgumentError;
VALUE eSwiftRuntimeError;
VALUE eSwiftConnectionError;

/*
  Initialize Swift with a non standard dbic++ path.

  @note
    By default Swift looks in '/usr/lib/dbic++/'. Not normally required unless you install dbic++ somewhere funny.

  @overload init(path)
    @param [path] path Non standard dbic++ path.
*/
VALUE swift_init(VALUE self, VALUE path) {
  try { dbi::dbiInitialize(CSTRING(path)); } CATCH_DBI_EXCEPTIONS();
  return Qtrue;
}

/*
  Trace statement execution.

  @example Toggle tracing.
    Swift.trace true
    Swift.db.execute 'select * from users'
    Swift.trace false
  @example Block form.
    Swift.trace true do
      Swift.db.execute 'select * from users'
    end

  @overload trace(show = true, output = $stderr)
    @param [true, false] show   Optional trace toggle boolean.
    @param [IO]          output Optional output. Defaults to stderr.
*/
VALUE swift_trace(int argc, VALUE *argv, VALUE self) {
    VALUE flag, io;
    rb_io_t *fptr;
    int status, fd = 2; // defaults to stderr

    rb_scan_args(argc, argv, "02", &flag, &io);

    if (NIL_P(flag))
      flag = Qtrue;

    if (TYPE(flag) != T_TRUE && TYPE(flag) != T_FALSE)
        rb_raise(eSwiftArgumentError, "Swift#trace expects a boolean flag, got %s", CSTRING(flag));

    if (!NIL_P(io)) {
        GetOpenFile(rb_convert_type(io, T_FILE, "IO", "to_io"), fptr);
        fd = fptr->fd;
    }

    // block form trace
    if (rb_block_given_p()) {
      // orig values
      bool orig_trace    = dbi::_trace;
      int  orig_trace_fd = dbi::_trace_fd;

      dbi::trace(flag == Qtrue ? true : false, fd);
      VALUE block_result = rb_protect(rb_yield, Qnil, &status);
      dbi::trace(orig_trace, orig_trace_fd);

      if (status)
        rb_jump_tag(status);
      else
        return block_result;
    }
    else {
      dbi::trace(flag == Qtrue ? true : false, fd);
      return flag;
    }
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
    init_swift_attribute();
    init_swift_pool();
    init_swift_request();
    init_swift_result();
    init_swift_statement();
    init_swift_query();
    init_swift_datetime();

    rb_define_module_function(mSwift, "init",  RUBY_METHOD_FUNC(swift_init), 1);
    rb_define_module_function(mSwift, "trace", RUBY_METHOD_FUNC(swift_trace), -1);

    // NOTE
    // Swift adapter and statement objects need to be deallocated or garbage collected in the reverse
    // allocation order. rb_gc() does that but gc at exit time seems to do it in allocation order which
    // stuffs up dbic++ destructors.
    rb_set_end_proc(atexit_caller, rb_proc_new(atexit_gc, mSwift));
  }
}

