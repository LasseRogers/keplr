#include "gpu.cuh"
#include "check.hpp"
#include "cuda_check.cuh"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <random>
#include <vector>

int main() {
    // Synthetic orbits spanning NEO element ranges, so the test needs no downloaded data.
    constexpr int n = 100'000;
    std::mt19937_64 rng(42);
    auto uni = [&](double lo, double hi) { return std::uniform_real_distribution<double>(lo, hi)(rng); };

    std::vector<Orbit> orbits(n);
    for (int k = 0; k < n; ++k)
        orbits[k] = {k,              2461200.5,       uni(0.0, 0.99),  uni(0.5, 5.0),
                     uni(0.0, 180.0), uni(0.0, 360.0), uni(0.0, 360.0), uni(0.0, 360.0)};
    const double t = 2461200.5 + 36525.0;  // a century past epoch

    Orbit* d_orbits;
    Vec3* d_out;
    CUDA_CHECK(cudaMalloc(&d_orbits, n * sizeof(Orbit)));
    CUDA_CHECK(cudaMalloc(&d_out, n * sizeof(Vec3)));
    CUDA_CHECK(cudaMemcpy(d_orbits, orbits.data(), n * sizeof(Orbit), cudaMemcpyHostToDevice));

    propagate_gpu(d_orbits, d_out, n, t);

    std::vector<Vec3> gpu(n);
    CUDA_CHECK(cudaMemcpy(gpu.data(), d_out, n * sizeof(Vec3), cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaFree(d_orbits));
    CUDA_CHECK(cudaFree(d_out));

    double worst = 0.0;
    for (int k = 0; k < n; ++k) {
        const Vec3 c = position(orbits[k], t);
        const double dx = gpu[k].x - c.x, dy = gpu[k].y - c.y, dz = gpu[k].z - c.z;
        worst = std::max(worst, std::sqrt(dx * dx + dy * dy + dz * dz));
    }
    std::printf("max |gpu - cpu| = %.3e AU\n", worst);

    // Not bit-exact: nvcc fuses multiply-adds and CUDA's sin/cos differ from libm in the last
    // bit; high-e orbits near periapsis amplify that. 1e-8 AU is about 1.5 km.
    CHECK(worst < 1e-8);
    return report();
}
