#include "query.h"

ID fstrftime, fto_s, fusec;
VALUE dtformat, tzformat, utf8;

VALUE query_execute(Query *query) {
  try {
    return UINT2NUM(
      query->bind.size() == 0
        ? query->handle->conn()->execute(query->sql)
        : query->handle->conn()->execute(query->sql, query->bind)
    );
  }
  catch (dbi::Error &e) {
    snprintf(query->error, 8192, "%s", e.what());
    return Qfalse;
  }
}

VALUE query_execute_statement(Query *query) {
  try {
    return UINT2NUM(
      query->bind.size() == 0
        ? query->statement->execute()
        : query->statement->execute(query->bind)
    );
  }
  catch (dbi::Error &e) {
    snprintf(query->error, 8192, "%s", e.what());
    return Qfalse;
  }
}

void query_bind_values(Query *query, VALUE bind_values) {
  for (int i = 0; i < RARRAY_LEN(bind_values); i++) {
    VALUE bind_value = rb_ary_entry(bind_values, i);

    if (bind_value == Qnil) {
      query->bind.push_back(dbi::PARAM(dbi::null()));
    }
    else if (bind_value == Qtrue) {
      query->bind.push_back(dbi::PARAM("1"));
    }
    else if (bind_value == Qfalse) {
      query->bind.push_back(dbi::PARAM("0"));
    }
    else if (rb_obj_is_kind_of(bind_value, rb_cIO) ==  Qtrue || rb_obj_is_kind_of(bind_value, cStringIO) ==  Qtrue) {
      bind_value = rb_funcall(bind_value, rb_intern("read"), 0);
      query->bind.push_back(dbi::PARAM_BINARY((unsigned char*)RSTRING_PTR(bind_value), RSTRING_LEN(bind_value)));
    }
    // TODO convert timestamps to server timezone if @timezone is set in adapter.
    else if (rb_obj_is_kind_of(bind_value, rb_cTime)) {
      std::string timestamp = RSTRING_PTR(rb_funcall(bind_value, fstrftime, 1, dtformat));

      timestamp += RSTRING_PTR(rb_funcall(rb_funcall(bind_value, fusec, 0), fto_s, 0));
      timestamp += RSTRING_PTR(rb_funcall(bind_value, fstrftime, 1, tzformat));

      query->bind.push_back(dbi::PARAM(timestamp));
    }
    else {
      bind_value = TO_S(bind_value);
      if (strcmp(rb_enc_get(bind_value)->name, "UTF-8") != 0)
        bind_value = rb_str_encode(bind_value, utf8, 0, Qnil);
      query->bind.push_back(dbi::PARAM((unsigned char*)RSTRING_PTR(bind_value), RSTRING_LEN(bind_value)));
    }
  }
}

void init_swift_query() {
  fstrftime = rb_intern("strftime");
  fto_s     = rb_intern("to_s");
  fusec     = rb_intern("usec");
  dtformat  = rb_str_new2("%F %T.");
  tzformat  = rb_str_new2("%z");
  utf8      = rb_str_new2("UTF-8");

  rb_global_variable(&utf8);
  rb_global_variable(&tzformat);
  rb_global_variable(&dtformat);
}
