#include "gpu.cuh"

#include "cuda_check.cuh"

namespace {

// One thread per orbit: every asteroid is independent, so no synchronisation is needed.
__global__ void propagate_kernel(const Orbit* orbits, Vec3* out, int n, double t) {
    const int k = blockIdx.x * blockDim.x + threadIdx.x;
    if (k < n) out[k] = position(orbits[k], t);
}

__global__ void approach_kernel(const Orbit* orbits, const Vec3* earth, Approach* out, int n,
                                double t0, double dt, int steps) {
    const int k = blockIdx.x * blockDim.x + threadIdx.x;
    if (k >= n) return;
    const Approach coarse = closest_approach(orbits[k], earth, t0, dt, steps);
    out[k] = refine_approach(orbits[k], coarse, dt);
}

constexpr int kBlock = 256;

int blocks(int n) { return (n + kBlock - 1) / kBlock; }

}  // namespace

void propagate_gpu(const Orbit* orbits, Vec3* out, int n, double t, cudaStream_t stream) {
    propagate_kernel<<<blocks(n), kBlock, 0, stream>>>(orbits, out, n, t);
    CUDA_CHECK(cudaGetLastError());
}

void approach_gpu(const Orbit* orbits, const Vec3* earth, Approach* out, int n, double t0,
                  double dt, int steps, cudaStream_t stream) {
    approach_kernel<<<blocks(n), kBlock, 0, stream>>>(orbits, earth, out, n, t0, dt, steps);
    CUDA_CHECK(cudaGetLastError());
}
