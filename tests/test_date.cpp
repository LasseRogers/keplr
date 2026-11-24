#include "date.hpp"
#include "check.hpp"

static bool is(Date d, int y, int m, int day) { return d.year == y && d.month == m && d.day == day; }

int main() {
    CHECK(is(jd_to_date(2451545.0), 2000, 1, 1));    // J2000, noon
    CHECK(is(jd_to_date(2451603.5), 2000, 2, 29));   // leap day
    CHECK(is(jd_to_date(2451604.5), 2000, 3, 1));
    CHECK(is(jd_to_date(2461041.5), 2026, 1, 1));
    CHECK(is(jd_to_date(2461200.5), 2026, 6, 9));    // epoch of data/neo.csv
    CHECK(is(jd_to_date(2436116.31), 1957, 10, 4));  // Meeus, example 7.c
    return report();
}
