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

# Separate from keplr_core so CPU-only code never links the CUDA runtime.
add_library(keplr_gpu src/gpu.cu)
target_link_libraries(keplr_gpu PUBLIC keplr_core)

add_executable(test_gpu tests/test_gpu.cu)
target_link_libraries(test_gpu PRIVATE keplr_gpu)
add_test(NAME gpu COMMAND test_gpu)

add_executable(test_earth tests/test_earth.cpp)
target_link_libraries(test_earth PRIVATE keplr_core)
add_test(NAME earth COMMAND test_earth)

add_executable(test_approach tests/test_approach.cu)
target_link_libraries(test_approach PRIVATE keplr_gpu)
add_test(NAME approach COMMAND test_approach)

add_executable(test_date tests/test_date.cpp)
target_include_directories(test_date PRIVATE src)
add_test(NAME date COMMAND test_date)

add_executable(keplr src/main.cu)
target_link_libraries(keplr PRIVATE keplr_gpu)

add_executable(test_refine tests/test_refine.cpp)
target_link_libraries(test_refine PRIVATE keplr_core)
add_test(NAME refine COMMAND test_refine)

# NVIDIA's simpleGL sample, vendored unchanged as the starting point for the viewer.
find_package(OpenGL REQUIRED)
find_package(GLUT REQUIRED)

add_executable(simplegl third_party/cuda-samples/simpleGL/simpleGL.cu)
target_include_directories(simplegl SYSTEM PRIVATE third_party/cuda-samples/Common)
target_link_libraries(simplegl PRIVATE OpenGL::GL OpenGL::GLU GLUT::GLUT)
