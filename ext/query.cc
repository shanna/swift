#include "query.h"
#include <math.h>

ID fstrftime, fusec, fto_s, fto_f, fto_time;
VALUE dtformat, tzformat, utf8;
VALUE cDateTime;

VALUE query_execute(Query *query) {
  try {
    return UINT2NUM(
      query->bind.size() == 0
        ? query->handle->conn()->execute(query->sql)
        : query->handle->conn()->execute(query->sql, query->bind)
    );
  }
  catch (dbi::ConnectionError &e) {
    query->error_klass = eSwiftConnectionError;
    snprintf(query->error_message, 8192, "%s", e.what());
  }
  catch (dbi::Error &e) {
    query->error_klass = eSwiftRuntimeError;
    snprintf(query->error_message, 8192, "%s", e.what());
  }
  catch (std::bad_alloc &e) {
    query->error_klass = rb_eNoMemError;
    snprintf(query->error_message, 8192, "%s", e.what());
  }
  catch (std::exception &e) {
    query->error_klass = rb_eRuntimeError;
    snprintf(query->error_message, 8192, "%s", e.what());
  }

  return Qfalse;
}

VALUE query_execute_statement(Query *query) {
  try {
    return UINT2NUM(
      query->bind.size() == 0
        ? query->statement->execute()
        : query->statement->execute(query->bind)
    );
  }
  catch (dbi::ConnectionError &e) {
    query->error_klass = eSwiftConnectionError;
    snprintf(query->error_message, 8192, "%s", e.what());
  }
  catch (dbi::Error &e) {
    query->error_klass = eSwiftRuntimeError;
    snprintf(query->error_message, 8192, "%s", e.what());
  }
  catch (std::bad_alloc &e) {
    query->error_klass = rb_eNoMemError;
    snprintf(query->error_message, 8192, "%s", e.what());
  }
  catch (std::exception &e) {
    query->error_klass = rb_eRuntimeError;
    snprintf(query->error_message, 8192, "%s", e.what());
  }

  return Qfalse;
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
    else if (rb_obj_is_kind_of(bind_value, rb_cTime) || rb_obj_is_kind_of(bind_value, cDateTime)) {
      std::string timestamp = RSTRING_PTR(rb_funcall(bind_value, fstrftime, 1, dtformat));
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
  rb_require("date");

  fstrftime = rb_intern("strftime");
  fto_s     = rb_intern("to_s");
  fto_f     = rb_intern("to_f");
  fto_time  = rb_intern("to_time");
  fusec     = rb_intern("usec");
  dtformat  = rb_str_new2("%F %T.%N %z");
  utf8      = rb_str_new2("UTF-8");
  cDateTime = CONST_GET(rb_mKernel, "DateTime");

  rb_global_variable(&utf8);
  rb_global_variable(&dtformat);
}
