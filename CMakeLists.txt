cmake_minimum_required(VERSION 3.24)

# CUDA 12.0 rejects GCC 13; must be set before project() enables CUDA.
set(CMAKE_CUDA_HOST_COMPILER g++-12 CACHE STRING "Host compiler for nvcc")
# Target the GPU in this machine rather than a generic architecture list.
set(CMAKE_CUDA_ARCHITECTURES native)

project(keplr LANGUAGES CXX CUDA)

set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)
# clangd picks up build/compile_commands.json on its own.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
