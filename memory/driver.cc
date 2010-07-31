#include "dbic++.h"
#include <unistd.h>

/*----------------------------------------------------------------------------------

   To compile:

   g++ -Iinc -Llibs -rdynamic -o driver driver.cc -ldbic++ -ldl -lpcrecpp -levent -lpthread -luuid

----------------------------------------------------------------------------------*/

using namespace std;
using namespace dbi;

char buffer[8192];

void fetchRows(Statement &st) {
    ResultRow r;
    while (r = st.fetchRow()) { }
}

void top() {
    sprintf(buffer, "top -n1 -bp %d | grep %s", getpid(), getlogin());
    FILE *top = popen(buffer, "r");
    fgets(buffer, 8192, top);
    pclose(top);
    buffer[strlen(buffer)-1] = 0;
    printf("%s", buffer);
}

int main(int argc, char *argv[]) {
    string driver(argc > 1 ? argv[1] : "postgresql");

    int rows = argc > 2 ? atoi(argv[2]) : 500;
    int iter = argc > 3 ? atoi(argv[3]) : 10;

    for (int times = 0; times < 50; times++) {
        Handle h (driver, getlogin(), "", "swift");

        printf("-- run %d --\n", times);
        top();

        // create test table
        h.execute("drop table if exists users");
        h.execute("create table users(id serial, name text, email text, created_at timestamp)");

        // insert some test data
        Statement ins (h, "insert into users(name, email, created_at) values(?, ?, now())");

        for (int n = 0; n < rows; n++) {
            sprintf(buffer, "test %d", n);
            ins % buffer;
            ins % "test@example.com";
            ins.execute();
        }

        Statement sel (h, "select id, name, email from users order by id");
        for (int n = 0; n < iter; n++) {
            sel.execute();
            fetchRows(sel);
        }

        Statement upd (h, "update users set name = ?, email = ? where id = ?");
        for (int n = 0; n < iter; n++) {
            sel.execute();
            for (int r = 0; r < sel.rows(); r++) {
                sprintf(buffer, "test %d", r);
                upd % buffer;
                upd % "test@example.com";
                upd % string((const char*)sel.fetchValue(r, 0, 0));
                upd.execute();
            }
        }

        ins.finish();
        sel.finish();
        upd.finish();
        h.close();
    }
}
