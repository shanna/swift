#ifndef SWIFT_RESULT_H
#define SWIFT_RESULT_H

#include "swift.h"

extern VALUE cSwiftResult;
extern VALUE cStringIO;

void init_swift_result();
void result_free(dbi::AbstractResultSet*);
VALUE result_each(VALUE);
dbi::AbstractResultSet* result_handle(VALUE);

VALUE typecast_field(int, const char*, uint64_t);
VALUE typecast_datetime(const char*, uint64_t);

#endif
