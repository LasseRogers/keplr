#pragma once
#include <cmath>

// Same source for host and device; plain C++ compilers never see the CUDA qualifiers.
#ifdef __CUDACC__
#define KEPLR_HD __host__ __device__
#else
#define KEPLR_HD
#endif

constexpr double kPi = 3.14159265358979323846;

// Eccentric anomaly E for mean anomaly M (radians) on an elliptic orbit (0 <= e < 1),
// i.e. the root of M = E - e sin E. Unqualified math calls resolve to the CUDA math
// library on the device and to libm on the host.
KEPLR_HD inline double solve_kepler(double M, double e) {
    // The starting guesses below assume M in [-pi, pi].
    M = remainder(M, 2.0 * kPi);
    // E0 = M stalls near periapsis for high e; starting at +-pi converges for any e < 1.
    double E = e < 0.8 ? M : (M < 0.0 ? -kPi : kPi);
    for (int k = 0; k < 30; ++k) {
        const double dE = (E - e * sin(E) - M) / (1.0 - e * cos(E));
        E -= dE;
        if (fabs(dE) < 1e-14) break;
    }
    return E;
}
