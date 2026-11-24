#include "approach.cuh"
#include "check.hpp"

#include <algorithm>
#include <cmath>
#include <random>

int main() {
    constexpr double t0 = 2461041.5, dt = 1.0, minute = 1.0 / 1440.0;
    constexpr int steps = 366;
    const auto earth = earth_table(t0, dt, steps);

    std::mt19937_64 rng(3);
    auto uni = [&](double lo, double hi) { return std::uniform_real_distribution<double>(lo, hi)(rng); };

    double worst_t = 0.0;
    for (int k = 0; k < 200; ++k) {
        const Orbit o{k,              2461200.5,       uni(0.0, 0.6),   uni(0.7, 1.5),
                      uni(0.0, 10.0), uni(0.0, 360.0), uni(0.0, 360.0), uni(0.0, 360.0)};
        const Approach coarse = closest_approach(o, earth.data(), t0, dt, steps);
        const Approach fine = refine_approach(o, coarse, dt);

        // Brute force: every minute within a day of the coarse sample.
        Approach brute{1e300, 0.0};
        for (double t = coarse.t - dt; t <= coarse.t + dt; t += minute) {
            const double d = std::sqrt(dist2_at(o, t));
            if (d < brute.dist) brute = {d, t};
        }

        CHECK(fine.dist <= coarse.dist);
        // At a span-edge minimum distance still slopes, and stopping ~1e-8 days from the edge
        // costs up to ~1e-10 AU there; interior minima are flat and match to rounding.
        CHECK(fine.dist <= brute.dist + 1e-9);
        worst_t = std::max(worst_t, std::fabs(fine.t - brute.t));
    }
    CHECK(worst_t < minute);

    return report();
}
