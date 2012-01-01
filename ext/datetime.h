#ifndef SWIFT_DATETIME_H
#define SWIFT_DATETIME_H

#include "swift.h"
#include <math.h>

void init_swift_datetime();
VALUE datetime_parse(VALUE klass, const char *data, uint64_t size);

extern VALUE cSwiftDateTime;

#endif
