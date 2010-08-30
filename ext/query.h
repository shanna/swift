#ifndef SWIFT_QUERY_H
#define SWIFT_QUERY_H

#include "swift.h"

struct Query {
  char                   *sql;
  dbi::Handle            *handle;
  dbi::AbstractStatement *statement;
  dbi::ResultRow         bind;
  const char             *error;
};

VALUE query_execute(Query*);
VALUE query_execute_statement(Query*);
void query_bind_values(Query*, VALUE);

#endif
