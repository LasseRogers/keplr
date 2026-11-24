#pragma once
#include <vector>

#include "propagate.cuh"

struct Approach {
    double dist;  // AU
    double t;     // JD TDB
};

// Closest of `steps` samples at t0 + k*dt between orbit o and Earth, whose positions at the
// same instants are precomputed in `earth`. Threads walk the table in lockstep, so each entry
// is one broadcast load instead of a Kepler solve per asteroid per step.
// Sampling can miss the true minimum by up to dt of relative motion.
KEPLR_HD inline Approach closest_approach(const Orbit& o, const Vec3* earth, double t0,
                                          double dt, int steps) {
    double best_d2 = 1e300, best_t = t0;
    for (int k = 0; k < steps; ++k) {
        const double t = t0 + k * dt;
        const Vec3 p = position(o, t);
        const double dx = p.x - earth[k].x, dy = p.y - earth[k].y, dz = p.z - earth[k].z;
        const double d2 = dx * dx + dy * dy + dz * dz;
        if (d2 < best_d2) {
            best_d2 = d2;
            best_t = t;
        }
    }
    return {sqrt(best_d2), best_t};
}

// Earth's position at every sample instant, built once on the host.
inline std::vector<Vec3> earth_table(const Orbit& earth, double t0, double dt, int steps) {
    std::vector<Vec3> table(steps);
    for (int k = 0; k < steps; ++k) table[k] = position(earth, t0 + k * dt);
    return table;
}
