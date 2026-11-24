#include "script.hpp"

#include <lua.hpp>

#include <stdexcept>

void Script::LuaDeleter::operator()(lua_State* L) const { lua_close(L); }

namespace {

// Pops Lua's error message off the stack into an exception.
std::runtime_error lua_failure(lua_State* L, const char* what) {
    std::string msg = std::string(what) + ": " + lua_tostring(L, -1);
    lua_pop(L, 1);
    return std::runtime_error(msg);
}

void set_number(lua_State* L, const char* key, double value) {
    lua_pushnumber(L, value);
    lua_setfield(L, -2, key);
}

}  // namespace

Script Script::from_file(const std::string& path) { return make(path, true); }
Script Script::from_string(const std::string& source) { return make(source, false); }

Script Script::make(const std::string& source_or_path, bool is_file) {
    Script s(luaL_newstate());
    lua_State* L = s.L_.get();
    luaL_openlibs(L);

    const int status = is_file ? luaL_dofile(L, source_or_path.c_str())
                               : luaL_dostring(L, source_or_path.c_str());
    if (status != LUA_OK) throw lua_failure(L, "loading script");

    lua_getglobal(L, "color");
    const bool has_color = lua_isfunction(L, -1);
    lua_pop(L, 1);
    if (!has_color) throw std::runtime_error("script defines no color(a) function");
    return s;
}

std::optional<Color> Script::color(const Orbit& o, const Approach& approach) {
    lua_State* L = L_.get();
    lua_getglobal(L, "color");

    lua_createtable(L, 0, 9);
    lua_pushinteger(L, o.spkid);
    lua_setfield(L, -2, "spkid");
    set_number(L, "a", o.a);
    set_number(L, "e", o.e);
    set_number(L, "i", o.i);
    set_number(L, "om", o.om);
    set_number(L, "w", o.w);
    set_number(L, "ma", o.ma);
    set_number(L, "dist", approach.dist);
    set_number(L, "t", approach.t);

    // Protected call: a Lua error must not longjmp through C++ frames. Missing results pad to nil.
    if (lua_pcall(L, 1, 3, 0) != LUA_OK) throw lua_failure(L, "color()");

    std::optional<Color> out;
    if (!lua_isnil(L, -3)) {
        int ok_r = 0, ok_g = 0, ok_b = 0;
        const Color c{static_cast<float>(lua_tonumberx(L, -3, &ok_r)),
                      static_cast<float>(lua_tonumberx(L, -2, &ok_g)),
                      static_cast<float>(lua_tonumberx(L, -1, &ok_b))};
        if (!(ok_r && ok_g && ok_b)) {
            lua_pop(L, 3);
            throw std::runtime_error("color() must return three numbers or nil");
        }
        out = c;
    }
    lua_pop(L, 3);
    return out;
}
