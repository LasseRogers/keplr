#include "propagate.cuh"

#include <cmath>
#include <cstdio>

static int failures = 0;

#define CHECK(cond)                                                            \
    do {                                                                       \
        if (!(cond)) {                                                         \
            std::fprintf(stderr, "%s:%d: CHECK(%s)\n", __FILE__, __LINE__, #cond); \
            ++failures;                                                        \
        }                                                                      \
    } while (0)

static double norm(Vec3 v) { return std::sqrt(v.x * v.x + v.y * v.y + v.z * v.z); }

int main() {
    // 433 Eros, first row of data/neo.csv.
    const Orbit eros{20000433,          2461200.5,         .2228779627700761, 1.458243716760167,
                     10.82854410314273, 304.2679713350896, 178.9181319135911, 62.51145501986792};

    // Distance to the Sun at periapsis and apoapsis is fixed by a and e alone.
    Orbit p = eros;
    p.ma = 0.0;
    CHECK(std::fabs(norm(position(p, p.epoch)) - eros.a * (1.0 - eros.e)) < 1e-12);
    p.ma = 180.0;
    CHECK(std::fabs(norm(position(p, p.epoch)) - eros.a * (1.0 + eros.e)) < 1e-12);

    // Eros's known orbital period is about 643 days.
    const double period = 2.0 * kPi / mean_motion(eros.a);
    CHECK(period > 640.0 && period < 646.0);

    // One full period later the asteroid is back where it started.
    const double t0 = eros.epoch + 123.4;
    const Vec3 a = position(eros, t0), b = position(eros, t0 + period);
    CHECK(norm({a.x - b.x, a.y - b.y, a.z - b.z}) < 1e-9);

    // With all angles zero the orbit lies in the ecliptic, periapsis on the +x axis.
    const Orbit flat{0, 0.0, 0.5, 2.0, 0.0, 0.0, 0.0, 0.0};
    const Vec3 q = position(flat, 0.0);
    CHECK(std::fabs(q.x - 1.0) < 1e-12 && std::fabs(q.y) < 1e-12 && q.z == 0.0);

    if (failures == 0) std::puts("ok");
    return failures == 0 ? 0 : 1;
}
