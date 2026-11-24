cmake_minimum_required(VERSION 3.24)

# CUDA 12.0 rejects GCC 13; must be set before project() enables CUDA.
set(CMAKE_CUDA_HOST_COMPILER g++-12 CACHE STRING "Host compiler for nvcc")
# Target the GPU in this machine rather than a generic architecture list.
set(CMAKE_CUDA_ARCHITECTURES native)

project(keplr LANGUAGES C CXX CUDA)

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

add_executable(viewer src/viewer.cu)
target_include_directories(viewer SYSTEM PRIVATE third_party/cuda-samples/Common)
target_link_libraries(viewer PRIVATE keplr_gpu OpenGL::GL OpenGL::GLU GLUT::GLUT)

# Lua is embedded from source, pinned by hash, so the project decides its own Lua version.
include(FetchContent)
FetchContent_Declare(lua
    URL https://www.lua.org/ftp/lua-5.4.8.tar.gz
    URL_HASH SHA256=4f18ddae154e793e46eeab727c59ef1c0c0c2b744e7b94219710d76f530629ae
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
FetchContent_MakeAvailable(lua)

# Everything but the standalone interpreter and compiler, which carry their own main().
file(GLOB LUA_SOURCES ${lua_SOURCE_DIR}/src/*.c)
list(REMOVE_ITEM LUA_SOURCES ${lua_SOURCE_DIR}/src/lua.c ${lua_SOURCE_DIR}/src/luac.c)
add_library(lua STATIC ${LUA_SOURCES})
target_include_directories(lua SYSTEM PUBLIC ${lua_SOURCE_DIR}/src)
target_compile_definitions(lua PRIVATE LUA_USE_LINUX)
target_link_libraries(lua PUBLIC m ${CMAKE_DL_LIBS})

add_executable(test_lua tests/test_lua.cpp)
target_link_libraries(test_lua PRIVATE lua)
add_test(NAME lua COMMAND test_lua)
