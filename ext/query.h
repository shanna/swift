#ifndef SWIFT_QUERY_H
#define SWIFT_QUERY_H

#include "swift.h"

struct Query {
  char                   *sql;
  dbi::Handle            *handle;
  dbi::AbstractStatement *stmt;
  dbi::ResultRow         bind;
};

VALUE query_execute(Query*);
void query_bind_values(Query*, VALUE);

#endif
