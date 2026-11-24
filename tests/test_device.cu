#include "cuda_check.cuh"

__global__ void add(const float* a, const float* b, float* out, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) out[i] = a[i] + b[i];
}

int main() {
    constexpr int n = 1 << 20;
    float *a, *b, *out;
    // Managed memory keeps the smoke test free of explicit copies.
    CUDA_CHECK(cudaMallocManaged(&a, n * sizeof(float)));
    CUDA_CHECK(cudaMallocManaged(&b, n * sizeof(float)));
    CUDA_CHECK(cudaMallocManaged(&out, n * sizeof(float)));

    for (int i = 0; i < n; ++i) {
        a[i] = float(i);
        b[i] = 2.0f * i;
    }

    add<<<(n + 255) / 256, 256>>>(a, b, out, n);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    // Exact compare is safe: all values stay below 2^24.
    for (int i = 0; i < n; ++i) {
        if (out[i] != 3.0f * i) {
            std::fprintf(stderr, "mismatch at %d: %f\n", i, out[i]);
            return 1;
        }
    }

    CUDA_CHECK(cudaFree(a));
    CUDA_CHECK(cudaFree(b));
    CUDA_CHECK(cudaFree(out));
    std::puts("ok");
}
