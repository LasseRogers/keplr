#pragma once
#include <cuda_runtime.h>

#include "propagate.cuh"

// Positions of n orbits at time t (JD TDB). Both pointers are device memory; runs on `stream`.
void propagate_gpu(const Orbit* orbits, Vec3* out, int n, double t, cudaStream_t stream = 0);
