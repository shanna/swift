#ifndef SWIFT_ADAPTER_H
#define SWIFT_ADAPTER_H

#include "swift.h"
#include "query.h"
#include "statement.h"

void init_swift_adapter();
dbi::Handle *adapter_handle(VALUE);

#endif

