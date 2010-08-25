#include "iostream.h"

IOStream::IOStream(VALUE s) {
  stream = s;
}

std::string& IOStream::read() {
  VALUE response = rb_funcall(stream, fRead, 0);
  if (response == Qnil) {
    return empty;
  }
  else {
    // Attempt TO_S first before complaining?
    if (TYPE(response) != T_STRING) {
      rb_raise(
        eArgumentError,
        "Write can only process string data. You need to stringify values returned in the callback."
      );
    }
    data = string(RSTRING_PTR(response), RSTRING_LEN(response));
    return data;
  }
}

uint IOStream::read(char *buffer, uint length) {
  VALUE response = rb_funcall(stream, rb_intern("read"), 1, INT2NUM(length));
  if (response == Qnil) {
    return 0;
  }
  else {
    length = length < RSTRING_LEN(response) ? length : RSTRING_LEN(response);
    memcpy(buffer, RSTRING_PTR(response), length);
    return length;
  }
}

void IOStream::write(const char *str) {
  rb_funcall(stream, rb_intern("write"), 1, rb_str_new2(str));
}

void IOStream::write(const char *str, ulong l) {
  rb_funcall(stream, rb_intern("write"), 1, rb_str_new(str, l));
}

