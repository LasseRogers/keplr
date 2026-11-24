#include "orbit.hpp"

#include <cstdio>
#include <sstream>
#include <stdexcept>

static int failures = 0;

#define CHECK(cond)                                                            \
    do {                                                                       \
        if (!(cond)) {                                                         \
            std::fprintf(stderr, "%s:%d: CHECK(%s)\n", __FILE__, __LINE__, #cond); \
            ++failures;                                                        \
        }                                                                      \
    } while (0)

static bool throws(const char* csv) {
    std::istringstream in(csv);
    try {
        load_orbits(in);
    } catch (const std::runtime_error&) {
        return true;
    }
    return false;
}

int main() {
    // First two rows of data/neo.csv: 433 Eros and 719 Albert.
    std::istringstream in(
        "spkid,epoch,e,a,i,om,w,ma\n"
        "20000433,2461200.5,.2228779627700761,1.458243716760167,10.82854410314273,"
        "304.2679713350896,178.9181319135911,62.51145501986792\n"
        "20000719,2461200.5,.54659281141853,2.636949566436567,11.57235893021322,"
        "183.8602907856791,156.1759693786955,286.6772166822684\n");
    const auto orbits = load_orbits(in);

    CHECK(orbits.size() == 2);
    CHECK(orbits[0].spkid == 20000433);
    CHECK(orbits[0].epoch == 2461200.5);
    // Exact compare: from_chars and the compiler both round the literal correctly.
    CHECK(orbits[0].a == 1.458243716760167);
    CHECK(orbits[1].e == .54659281141853);
    CHECK(orbits[1].ma == 286.6772166822684);

    CHECK(throws("wrong,header\n"));
    CHECK(throws("spkid,epoch,e,a,i,om,w,ma\n1,2,3\n"));
    CHECK(throws("spkid,epoch,e,a,i,om,w,ma\n1,2,3,4,5,6,7,x\n"));

    if (failures == 0) std::puts("ok");
    return failures == 0 ? 0 : 1;
}
