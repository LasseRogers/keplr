#include "gpu.cuh"
#include "check.hpp"
#include "cuda_check.cuh"
#include "earth.hpp"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <random>
#include <vector>

int main() {
    constexpr double t0 = 2461041.5, dt = 1.0;  // daily from 2026-01-01
    constexpr int steps = 3653;                 // ten years
    const auto earth = earth_table(kEarth, t0, dt, steps);

    // A body sharing Earth's orbit never leaves it.
    CHECK(closest_approach(kEarth, earth.data(), t0, dt, steps).dist < 1e-12);

    // Earth-crossing synthetic orbits: the GPU must reproduce the CPU search.
    constexpr int n = 2000;
    std::mt19937_64 rng(7);
    auto uni = [&](double lo, double hi) { return std::uniform_real_distribution<double>(lo, hi)(rng); };
    std::vector<Orbit> orbits(n);
    for (int k = 0; k < n; ++k)
        orbits[k] = {k,              2461200.5,       uni(0.0, 0.6),   uni(0.7, 1.5),
                     uni(0.0, 10.0), uni(0.0, 360.0), uni(0.0, 360.0), uni(0.0, 360.0)};

    Orbit* d_orbits;
    Vec3* d_earth;
    Approach* d_out;
    CUDA_CHECK(cudaMalloc(&d_orbits, n * sizeof(Orbit)));
    CUDA_CHECK(cudaMalloc(&d_earth, steps * sizeof(Vec3)));
    CUDA_CHECK(cudaMalloc(&d_out, n * sizeof(Approach)));
    CUDA_CHECK(cudaMemcpy(d_orbits, orbits.data(), n * sizeof(Orbit), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_earth, earth.data(), steps * sizeof(Vec3), cudaMemcpyHostToDevice));

    approach_gpu(d_orbits, d_earth, d_out, n, t0, dt, steps);

    std::vector<Approach> gpu(n);
    CUDA_CHECK(cudaMemcpy(gpu.data(), d_out, n * sizeof(Approach), cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaFree(d_orbits));
    CUDA_CHECK(cudaFree(d_earth));
    CUDA_CHECK(cudaFree(d_out));

    double worst_d = 0.0, worst_t = 0.0;
    for (int k = 0; k < n; ++k) {
        const Approach c = closest_approach(orbits[k], earth.data(), t0, dt, steps);
        worst_d = std::max(worst_d, std::fabs(gpu[k].dist - c.dist));
        worst_t = std::max(worst_t, std::fabs(gpu[k].t - c.t));
    }
    std::printf("max |gpu - cpu|: dist %.3e AU, time %.1f days\n", worst_d, worst_t);

    CHECK(worst_d < 1e-9);
    // A near-tie between neighbouring samples may resolve differently under FMA.
    CHECK(worst_t <= dt);
    return report();
}
