#include "earth.hpp"
#include "check.hpp"
#include "propagate.cuh"

#include <cmath>

int main() {
    // Sidereal year.
    const double period = 2.0 * kPi / mean_motion(kEarth.a);
    CHECK(std::fabs(period - 365.256) < 0.01);

    // The 2026 perihelion was on 3 January at 0.9833 AU; scan the year hour by hour.
    constexpr double jan1_2026 = 2461041.5;
    double best_r = 1e9, best_t = 0.0;
    for (int h = 0; h < 365 * 24; ++h) {
        const double t = jan1_2026 + h / 24.0;
        const Vec3 p = position(kEarth, t);
        const double r = std::sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
        if (r < best_r) {
            best_r = r;
            best_t = t;
        }
    }
    CHECK(best_t - jan1_2026 > 2.0 && best_t - jan1_2026 < 4.0);
    CHECK(std::fabs(best_r - 0.98329) < 1e-4);

    return report();
}
