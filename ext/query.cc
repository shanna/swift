#include "query.h"

VALUE query_execute(Query *query) {
  return UINT2NUM(
    query->bind.size() == 0
      ? query->handle->conn()->execute(query->sql)
      : query->handle->conn()->execute(query->sql, query->bind)
  );
}

VALUE query_execute_statement(Query *query) {
  return UINT2NUM(
    query->bind.size() == 0
      ? query->statement->execute()
      : query->statement->execute(query->bind)
  );
}

void query_bind_values(Query *query, VALUE bind_values) {
  for (int i = 0; i < RARRAY_LEN(bind_values); i++) {
    VALUE bind_value = rb_ary_entry(bind_values, i);

    if (bind_value == Qnil) {
      query->bind.push_back(dbi::PARAM(dbi::null()));
    }
    else if (rb_obj_is_kind_of(bind_value, rb_cIO) ==  Qtrue || rb_obj_is_kind_of(bind_value, CONST_GET(rb_mKernel, "StringIO")) ==  Qtrue) {
      bind_value = rb_funcall(bind_value, rb_intern("read"), 0);
      query->bind.push_back(dbi::PARAM_BINARY((unsigned char*)RSTRING_PTR(bind_value), RSTRING_LEN(bind_value)));
    }
    else {
      bind_value = TO_S(bind_value);
      if (strcmp(rb_enc_get(bind_value)->name, "UTF-8") != 0)
        bind_value = rb_str_encode(bind_value, rb_str_new2("UTF-8"), 0, Qnil);
      query->bind.push_back(dbi::PARAM((unsigned char*)RSTRING_PTR(bind_value), RSTRING_LEN(bind_value)));
    }
  }
}

