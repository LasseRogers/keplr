#pragma once
#include <memory>
#include <optional>
#include <string>

#include "approach.cuh"
#include "orbit.hpp"

struct lua_State;

struct Color {
    float r, g, b;
};

// A user Lua script deciding how each asteroid is drawn. It must define
//   color(a) -> r, g, b (each 0..1), or nil to hide the asteroid,
// where `a` has the SBDB elements spkid, a, e, i, om, w, ma and the closest approach to Earth
// as dist (AU) and t (JD TDB). Every Lua failure surfaces as std::runtime_error.
class Script {
public:
    static Script from_file(const std::string& path);
    static Script from_string(const std::string& source);

    std::optional<Color> color(const Orbit& o, const Approach& approach);

private:
    struct LuaDeleter {
        void operator()(lua_State* L) const;
    };

    static Script make(const std::string& source_or_path, bool is_file);
    explicit Script(lua_State* L) : L_(L) {}

    std::unique_ptr<lua_State, LuaDeleter> L_;
};
