#include "swift.h"

static VALUE mSwift;

extern "C" {
  void Init_swift(void) {
    mSwift = rb_define_module("Swift");

    init_swift_adapter();
    /*
    init_swift_statement();
    init_swift_result();
    ...
    */
  }
}

