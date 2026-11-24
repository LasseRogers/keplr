#pragma once
#include <cstdio>
#include <cstdlib>
#include <cuda_runtime.h>

// Abort on the first CUDA error: there is no sensible recovery in this tool.
#define CUDA_CHECK(call)                                                   \
    do {                                                                   \
        cudaError_t err_ = (call);                                         \
        if (err_ != cudaSuccess) {                                         \
            std::fprintf(stderr, "%s:%d: %s\n", __FILE__, __LINE__,        \
                         cudaGetErrorString(err_));                        \
            std::exit(EXIT_FAILURE);                                       \
        }                                                                  \
    } while (0)
