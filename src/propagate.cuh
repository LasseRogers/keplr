#pragma once
#include "kepler.cuh"
#include "orbit.hpp"

struct Vec3 {
    double x, y, z;
};

// Gaussian gravitational constant, sqrt(GM_sun) in AU^1.5/day: the unit system SBDB uses.
constexpr double kGauss = 0.01720209895;

// Radians per day.
KEPLR_HD inline double mean_motion(double a) { return kGauss / (a * sqrt(a)); }

// Heliocentric ecliptic J2000 position in AU at time t (JD TDB). Two-body only: planetary
// perturbations are ignored, so accuracy degrades as |t - epoch| grows.
KEPLR_HD inline Vec3 position(const Orbit& o, double t) {
    constexpr double rad = kPi / 180.0;
    const double M = o.ma * rad + mean_motion(o.a) * (t - o.epoch);
    const double E = solve_kepler(M, o.e);

    // Perifocal frame: x toward periapsis, y 90 degrees ahead in the orbital plane.
    const double xp = o.a * (cos(E) - o.e);
    const double yp = o.a * sqrt(1.0 - o.e * o.e) * sin(E);

    const double cO = cos(o.om * rad), sO = sin(o.om * rad);
    const double cw = cos(o.w * rad), sw = sin(o.w * rad);
    const double ci = cos(o.i * rad), si = sin(o.i * rad);

    return {(cO * cw - sO * sw * ci) * xp - (cO * sw + sO * cw * ci) * yp,
            (sO * cw + cO * sw * ci) * xp - (sO * sw - cO * cw * ci) * yp,
            sw * si * xp + cw * si * yp};
}
