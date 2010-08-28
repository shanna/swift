#ifndef SWIFT_IOSTREAM_H
#define SWIFT_IOSTREAM_H

#include "swift.h"

class IOStream : public dbi::IOStream {
    private:
      VALUE stream;
    public:
      IOStream(VALUE);
      std::string& read();
      uint32_t read(char *, uint32_t);
      void write(const char *);
      void write(const char *, uint64_t);
};

#endif
