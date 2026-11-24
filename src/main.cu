#include "cuda_check.cuh"
#include "date.hpp"
#include "earth.cuh"
#include "gpu.cuh"
#include "orbit.hpp"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <numeric>
#include <string>
#include <vector>

namespace {

constexpr double kAuKm = 149'597'870.7;
constexpr double kLunarKm = 384'400.0;

void print_row(int rank, std::int64_t spkid, const Approach& a) {
    const Date d = jd_to_date(a.t);
    std::printf("%4d  %10lld  %04d-%02d-%02d  %.6f AU  %11.0f km  %7.2f LD\n", rank,
                static_cast<long long>(spkid), d.year, d.month, d.day, a.dist, a.dist * kAuKm,
                a.dist * kAuKm / kLunarKm);
}

}  // namespace

// Usage: keplr [orbits.csv] [years] [spkid to report]
int main(int argc, char** argv) {
    const std::string path = argc > 1 ? argv[1] : "data/neo.csv";
    const double years = argc > 2 ? std::atof(argv[2]) : 10.0;
    const long long watch = argc > 3 ? std::atoll(argv[3]) : 0;

    std::ifstream in(path);
    if (!in) {
        std::fprintf(stderr, "cannot open %s (run scripts/fetch_sbdb.py)\n", path.c_str());
        return 1;
    }
    const auto orbits = load_orbits(in);
    const int n = static_cast<int>(orbits.size());

    // Start at the elements' epoch, where the two-body model is most accurate.
    const double t0 = orbits.front().epoch, dt = 1.0;
    const int steps = static_cast<int>(years * 365.25);
    const auto earth = earth_table(t0, dt, steps);

    Orbit* d_orbits;
    Vec3* d_earth;
    Approach* d_out;
    CUDA_CHECK(cudaMalloc(&d_orbits, n * sizeof(Orbit)));
    CUDA_CHECK(cudaMalloc(&d_earth, steps * sizeof(Vec3)));
    CUDA_CHECK(cudaMalloc(&d_out, n * sizeof(Approach)));
    CUDA_CHECK(cudaMemcpy(d_orbits, orbits.data(), n * sizeof(Orbit), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_earth, earth.data(), steps * sizeof(Vec3), cudaMemcpyHostToDevice));

    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    CUDA_CHECK(cudaEventRecord(start));
    approach_gpu(d_orbits, d_earth, d_out, n, t0, dt, steps);
    CUDA_CHECK(cudaEventRecord(stop));
    CUDA_CHECK(cudaEventSynchronize(stop));
    float ms = 0.0f;
    CUDA_CHECK(cudaEventElapsedTime(&ms, start, stop));

    std::vector<Approach> results(n);
    CUDA_CHECK(cudaMemcpy(results.data(), d_out, n * sizeof(Approach), cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaFree(d_orbits));
    CUDA_CHECK(cudaFree(d_earth));
    CUDA_CHECK(cudaFree(d_out));

    std::printf("%d asteroids x %d days in %.0f ms\n\n", n, steps, ms);

    std::vector<int> order(n);
    std::iota(order.begin(), order.end(), 0);
    const int top = std::min(10, n);
    std::partial_sort(order.begin(), order.begin() + top, order.end(),
                      [&](int a, int b) { return results[a].dist < results[b].dist; });
    for (int r = 0; r < top; ++r) print_row(r + 1, orbits[order[r]].spkid, results[order[r]]);

    if (watch) {
        const auto it = std::find_if(orbits.begin(), orbits.end(),
                                     [&](const Orbit& o) { return o.spkid == watch; });
        if (it == orbits.end()) {
            std::printf("\n%lld not in %s\n", watch, path.c_str());
        } else {
            const Approach& a = results[it - orbits.begin()];
            const int rank = 1 + static_cast<int>(std::count_if(
                                     results.begin(), results.end(),
                                     [&](const Approach& o) { return o.dist < a.dist; }));
            std::printf("\n");
            print_row(rank, watch, a);
        }
    }
}
