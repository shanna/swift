#include "adapter_io.h"

AdapterIO::AdapterIO(VALUE s) {
  stream = s;
}

std::string& AdapterIO::read() {
  VALUE response = rb_funcall(stream, rb_intern("read"), 0);
  if (response == Qnil) {
    return empty;
  }
  else {
    // Attempt TO_S first before complaining?
    if (TYPE(response) != T_STRING) {
      rb_raise(
        CONST_GET(rb_mKernel, "ArgumentError"),
        "Write can only process string data. You need to stringify values returned in the callback."
      );
    }
    stringdata = std::string(RSTRING_PTR(response), RSTRING_LEN(response));
    return stringdata;
  }
}

uint32_t AdapterIO::read(char *buffer, uint32_t length) {
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

void AdapterIO::write(const char *str) {
  rb_funcall(stream, rb_intern("write"), 1, rb_str_new2(str));
}

void AdapterIO::write(const char *str, uint64_t l) {
  rb_funcall(stream, rb_intern("write"), 1, rb_str_new(str, l));
}

bool AdapterIO::readline(std::string &line) {
  VALUE response = rb_funcall(stream, rb_intern("gets"), 0);
  if (response == Qnil) {
    return false;
  }
  else {
    line = std::string(RSTRING_PTR(response), RSTRING_LEN(response));
    return true;
  }
}

char* AdapterIO::readline() {
  return readline(stringdata) ? (char*)stringdata.c_str() : 0;
}

void AdapterIO::truncate() {
  rb_funcall(stream, rb_intern("truncate"), 0);
}
