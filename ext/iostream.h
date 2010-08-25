#ifndef SWIFT_IOSTREAM_H
#define SWIFT_IOSTREAM_H

#include "swift.h"

class IOStream : public dbi::IOStream {
    private:
      VALUE stream;
    public:
      IOStream(VALUE);
      std::string& read();
      uint read(char *, uint);
      void write(const char *);
      void write(const char *, ulong);
};

#endif
