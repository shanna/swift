#include "request.h"

VALUE cSwiftRequest;

static void request_free(dbi::Request *request) {
    if(request) delete request;
}

VALUE request_alloc(VALUE klass) {
    dbi::Request *request = 0;
    return Data_Wrap_Struct(klass, 0, request_free, request);
}

static dbi::Request* request_handle(VALUE self) {
    dbi::Request *request;
    Data_Get_Struct(self, dbi::Request, request);
    if (!request) rb_raise(eSwiftRuntimeError, "Invalid object, did you forget to call #super ?");
    return request;
}

VALUE request_socket(VALUE self) {
    dbi::Request *request = request_handle(self);
    try {
        return INT2NUM(request->socket());
    }
    CATCH_DBI_EXCEPTIONS();
}

VALUE request_process(VALUE self) {
    dbi::Request *request = request_handle(self);
    try {
        return request->process() ? Qtrue : Qfalse;
    }
    CATCH_DBI_EXCEPTIONS();
}

void init_swift_request() {
  VALUE mSwift  = rb_define_module("Swift");
  cSwiftRequest = rb_define_class_under(mSwift, "Request", rb_cObject);

  rb_define_alloc_func(cSwiftRequest, request_alloc);
  rb_define_method(cSwiftRequest, "socket",  RUBY_METHOD_FUNC(request_socket),  0);
  rb_define_method(cSwiftRequest, "process", RUBY_METHOD_FUNC(request_process), 0);
}
