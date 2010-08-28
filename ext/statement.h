#ifndef SWIFT_STATEMENT_H
#define SWIFT_STATEMENT_H

#include "swift.h"

extern VALUE cSwiftStatement;

void init_swift_statement();
void statement_free(dbi::AbstractStatement*);

#endif

