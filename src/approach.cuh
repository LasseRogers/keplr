#pragma once
#include <vector>

#include "earth.cuh"
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

KEPLR_HD inline double dist2_at(const Orbit& o, double t) {
    const Vec3 p = position(o, t), q = earth_position(t);
    const double dx = p.x - q.x, dy = p.y - q.y, dz = p.z - q.z;
    return dx * dx + dy * dy + dz * dz;
}

// Golden-section search on [coarse.t - dt, coarse.t + dt]: the true minimum lies between the
// sampled neighbours, and distance is unimodal over so short a window. Evaluates Earth exactly
// rather than from the table. A minimum at the span's edge may refine slightly past it.
KEPLR_HD inline Approach refine_approach(const Orbit& o, Approach coarse, double dt) {
    constexpr double g = 0.6180339887498949;  // 1/phi
    double lo = coarse.t - dt, hi = coarse.t + dt;
    double x1 = hi - g * (hi - lo), x2 = lo + g * (hi - lo);
    double f1 = dist2_at(o, x1), f2 = dist2_at(o, x2);
    // Each iteration shrinks the window by 1/phi: 2 days * 0.618^40 is about a millisecond.
    for (int k = 0; k < 40; ++k) {
        if (f1 < f2) {
            hi = x2, x2 = x1, f2 = f1;
            x1 = hi - g * (hi - lo), f1 = dist2_at(o, x1);
        } else {
            lo = x1, x1 = x2, f1 = f2;
            x2 = lo + g * (hi - lo), f2 = dist2_at(o, x2);
        }
    }
    const double t = 0.5 * (lo + hi);
    return {sqrt(dist2_at(o, t)), t};
}

// Earth's position at every sample instant, built once on the host.
inline std::vector<Vec3> earth_table(double t0, double dt, int steps) {
    std::vector<Vec3> table(steps);
    for (int k = 0; k < steps; ++k) table[k] = earth_position(t0 + k * dt);
    return table;
}
