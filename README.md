# keplr

One CUDA thread per asteroid propagates JPL orbits and finds each one's closest approach to Earth.
The viewer, built on NVIDIA's simpleGL sample, draws them straight from GPU memory; embedded Lua
scripts color, filter and fly the camera.

```sh
cmake -B build && cmake --build build && ctest --test-dir build
uv run scripts/fetch_sbdb.py --all
./build/keplr data/all.csv 10
# Hybrid-GPU laptops give OpenGL to the iGPU by default; CUDA-GL interop needs it on the NVIDIA GPU.
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia ./build/viewer data/all.csv lua/groups.lua
```

Viewer: left-drag rotates, right-drag zooms, space pauses, `+`/`-` speed time up/down, `[`/`]` dim/brighten, Esc quits.
