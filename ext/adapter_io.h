#ifndef SWIFT_ADAPTER_IO_H
#define SWIFT_ADAPTER_IO_H

#include "swift.h"

class AdapterIO : public dbi::IO {
    private:
      VALUE stream;
      std::string stringdata, empty;
    public:
      AdapterIO(VALUE);
      std::string& read();
      uint32_t     read(char *, uint32_t);

      void write(const char *);
      void write(const char *, uint64_t);

      void truncate();

      bool  readline(string&);
      char* readline();
};

#endif
