#include "gpu.cuh"

#include "cuda_check.cuh"

namespace {

// One thread per orbit: every asteroid is independent, so no synchronisation is needed.
__global__ void propagate_kernel(const Orbit* orbits, Vec3* out, int n, double t) {
    const int k = blockIdx.x * blockDim.x + threadIdx.x;
    if (k < n) out[k] = position(orbits[k], t);
}

}  // namespace

void propagate_gpu(const Orbit* orbits, Vec3* out, int n, double t, cudaStream_t stream) {
    constexpr int block = 256;
    propagate_kernel<<<(n + block - 1) / block, block, 0, stream>>>(orbits, out, n, t);
    CUDA_CHECK(cudaGetLastError());
}

namespace {

__global__ void approach_kernel(const Orbit* orbits, const Vec3* earth, Approach* out, int n,
                                double t0, double dt, int steps) {
    const int k = blockIdx.x * blockDim.x + threadIdx.x;
    if (k < n) out[k] = closest_approach(orbits[k], earth, t0, dt, steps);
}

}  // namespace

void approach_gpu(const Orbit* orbits, const Vec3* earth, Approach* out, int n, double t0,
                  double dt, int steps, cudaStream_t stream) {
    constexpr int block = 256;
    approach_kernel<<<(n + block - 1) / block, block, 0, stream>>>(orbits, earth, out, n, t0, dt,
                                                                    steps);
    CUDA_CHECK(cudaGetLastError());
}
