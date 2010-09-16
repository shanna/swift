#!/usr/bin/ruby

require 'mkmf'

incdir = `pg_config --includedir`.chomp rescue ENV.fetch('POSTGRES_INCLUDE', '/usr/include/postgresql')
libdir = `pg_config --libdir`.chomp     rescue ENV.fetch('POSTGRES_LIB',     '/usr/lib')

$CFLAGS  = "-I#{incdir} -Os"
$LDFLAGS = "-L#{libdir} -lpq"

create_makefile 'pg_ext'
