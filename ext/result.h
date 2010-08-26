#ifndef SWIFT_RESULT_H
#define SWIFT_RESULT_H

#include "swift.h"

extern VALUE cSwiftResult;

void init_swift_result();
void result_free(dbi::AbstractResultSet*);
VALUE result_each(VALUE);

VALUE typecast_field(VALUE, int, const char*, ulong);
VALUE typecast_datetime(VALUE, const char*, ulong);

#endif
