#ifndef SWIFT_REQUEST_H
#define SWIFT_REQUEST_H

#include "swift.h"

extern VALUE cSwiftRequest;
VALUE request_alloc(VALUE klass);
void init_swift_request();

#endif
