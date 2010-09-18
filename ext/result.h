#ifndef SWIFT_RESULT_H
#define SWIFT_RESULT_H

#include "swift.h"

struct ResultWrapper {
  dbi::AbstractResult *result;
  VALUE adapter;
  bool free;
};

extern VALUE cSwiftResult;
extern VALUE cStringIO;

void init_swift_result();

void  result_free(ResultWrapper *);
void  result_mark(ResultWrapper *);

VALUE result_wrap_handle(VALUE, VALUE, dbi::AbstractResult *, bool free);
dbi::AbstractResult* result_handle(VALUE);

VALUE result_each(VALUE);

VALUE typecast_field(int, const char*, uint64_t, const char*);

#endif
