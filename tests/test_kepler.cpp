#include "kepler.cuh"
#include "check.hpp"

#include <cmath>
#include <cstdio>
#include <initializer_list>

static double deg(double rad) { return rad * 180.0 / kPi; }
static double rad(double deg) { return deg * kPi / 180.0; }

int main() {
    // Circular orbit: eccentric and mean anomaly coincide.
    CHECK(std::fabs(solve_kepler(1.234, 0.0) - 1.234) < 1e-15);

    // Vallado, Fundamentals of Astrodynamics, Example 2-1: M = 235.4 deg, e = 0.4.
    const double E = deg(solve_kepler(rad(235.4), 0.4));
    CHECK(std::fabs(std::remainder(E - 220.512074767522, 360.0)) < 1e-9);

    // The root must satisfy Kepler's equation for any M and e, including near-parabolic orbits.
    for (double e : {0.0, 0.1, 0.5, 0.8, 0.95, 0.99}) {
        for (double M = -10.0; M <= 10.0; M += 0.01) {
            const double Er = solve_kepler(M, e);
            const double residual = std::remainder(Er - e * std::sin(Er) - M, 2.0 * kPi);
            CHECK(std::fabs(residual) < 1e-12);
        }
    }

    return report();
}
