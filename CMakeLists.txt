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

enable_testing()

add_executable(test_device tests/test_device.cu)
target_include_directories(test_device PRIVATE src)
add_test(NAME device COMMAND test_device)

add_library(keplr_core src/orbit.cpp)
target_include_directories(keplr_core PUBLIC src)
target_compile_features(keplr_core PUBLIC cxx_std_17)

add_executable(test_orbit tests/test_orbit.cpp)
target_link_libraries(test_orbit PRIVATE keplr_core)
add_test(NAME orbit COMMAND test_orbit)

add_executable(test_kepler tests/test_kepler.cpp)
target_link_libraries(test_kepler PRIVATE keplr_core)
add_test(NAME kepler COMMAND test_kepler)

add_executable(test_propagate tests/test_propagate.cpp)
target_link_libraries(test_propagate PRIVATE keplr_core)
add_test(NAME propagate COMMAND test_propagate)
