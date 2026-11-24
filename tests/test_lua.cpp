#include <lua.hpp>  // Lua's C API wrapped in extern "C"

#include "check.hpp"

#include <cstring>

int main() {
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);

    CHECK(luaL_dostring(L, "return 6 * 7") == LUA_OK);
    CHECK(lua_tointeger(L, -1) == 42);
    lua_pop(L, 1);

    // Guards against a system Lua of another version sneaking onto the include path.
    CHECK(luaL_dostring(L, "return _VERSION") == LUA_OK);
    CHECK(std::strcmp(lua_tostring(L, -1), "Lua 5.4") == 0);

    lua_close(L);
    return report();
}
