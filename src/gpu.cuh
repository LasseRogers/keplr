#pragma once
#include <cuda_runtime.h>

#include "approach.cuh"
#include "propagate.cuh"

// Positions of n orbits at time t (JD TDB). Both pointers are device memory; runs on `stream`.
void propagate_gpu(const Orbit* orbits, Vec3* out, int n, double t, cudaStream_t stream = 0);

// Closest approach to Earth for n orbits: sampled over `steps` instants, then refined.
// `earth` is earth_table() copied to the device; all pointers are device memory.
void approach_gpu(const Orbit* orbits, const Vec3* earth, Approach* out, int n, double t0,
                  double dt, int steps, cudaStream_t stream = 0);
