#ifndef SWIFT_STATEMENT_H
#define SWIFT_STATEMENT_H

#include "swift.h"

struct StatementWrapper {
  dbi::AbstractStatement *statement;
  VALUE adapter;
  bool free;
};

extern VALUE cSwiftStatement;

void init_swift_statement();
void statement_free(StatementWrapper *);
void statement_mark(StatementWrapper *);

VALUE statement_wrap_handle(VALUE, VALUE, dbi::AbstractStatement *);
dbi::AbstractStatement* statement_handle(VALUE);

#endif

