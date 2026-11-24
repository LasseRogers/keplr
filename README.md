# keplr

One CUDA thread per asteroid propagates JPL orbits and finds each one's closest approach to Earth.
The viewer, built on NVIDIA's simpleGL sample, draws them straight from GPU memory; embedded Lua
scripts color, filter and fly the camera.

```sh
cmake -B build && cmake --build build && ctest --test-dir build
uv run scripts/fetch_sbdb.py --all
./build/keplr data/all.csv 10
./build/viewer data/all.csv lua/groups.lua
```
