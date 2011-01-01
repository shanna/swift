#ifndef SWIFT_QUERY_H
#define SWIFT_QUERY_H

#include "swift.h"

struct Query {
  char                    *sql;
  dbi::Handle             *handle;
  dbi::AbstractStatement  *statement;
  std::vector<dbi::Param> bind;
  const char              *error;
};

VALUE query_execute(Query*);
VALUE query_execute_statement(Query*);
void query_bind_values(Query*, VALUE);
void init_swift_query();

#endif
