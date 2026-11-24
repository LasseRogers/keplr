#pragma once
#include "propagate.cuh"

// Earth-Moon barycentre from JPL's "Keplerian Elements for Approximate Positions of the Major
// Planets" (Standish), Table 1: J2000 elements plus linear rates per Julian century, fit over
// 1800-2050 to about 6000 km in range. The rates matter: frozen J2000 elements put Earth
// ~145,000 km off by 2029, more than many close approaches.
KEPLR_HD inline Orbit earth_elements(double t) {
    const double T = (t - 2451545.0) / 36525.0;
    const double a = 1.00000261 + 0.00000562 * T;
    const double e = 0.01671123 - 0.00004392 * T;
    const double i = -0.00001531 - 0.01294668 * T;
    const double L = 100.46457166 + 35999.37244981 * T;
    const double peri = 102.93768193 + 0.32327364 * T;
    const double node = 0.0;
    // Osculating at t itself, so position() adds no mean motion of its own.
    return {3, t, e, a, i, node, peri - node, L - peri};
}

KEPLR_HD inline Vec3 earth_position(double t) { return position(earth_elements(t), t); }
