#include "earth.cuh"
#include "check.hpp"

#include <algorithm>
#include <cmath>

static double norm(Vec3 v) { return std::sqrt(v.x * v.x + v.y * v.y + v.z * v.z); }

int main() {
    // The 2026 perihelion was on 3 January at 0.9833 AU; scan the year hour by hour.
    constexpr double jan1_2026 = 2461041.5;
    double best_r = 1e9, best_t = 0.0;
    for (int h = 0; h < 365 * 24; ++h) {
        const double t = jan1_2026 + h / 24.0;
        const double r = norm(earth_position(t));
        if (r < best_r) {
            best_r = r;
            best_t = t;
        }
    }
    CHECK(best_t - jan1_2026 > 2.0 && best_t - jan1_2026 < 4.0);
    CHECK(std::fabs(best_r - 0.98330) < 1e-4);

    // One sidereal year later Earth points the same way again, up to the slow perihelion drift.
    constexpr double sidereal_year = 365.25636;
    const Vec3 a = earth_position(jan1_2026), b = earth_position(jan1_2026 + sidereal_year);
    const double cosang = (a.x * b.x + a.y * b.y + a.z * b.z) / (norm(a) * norm(b));
    CHECK(std::acos(std::min(1.0, cosang)) * 180.0 / kPi < 1e-3);

    return report();
}
