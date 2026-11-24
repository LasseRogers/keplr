#include "script.hpp"
#include "check.hpp"

#include <stdexcept>

static bool load_throws(const char* source) {
    try {
        Script::from_string(source);
    } catch (const std::runtime_error&) {
        return true;
    }
    return false;
}

static bool color_throws(const char* source, const Orbit& o, const Approach& a) {
    auto s = Script::from_string(source);
    try {
        s.color(o, a);
    } catch (const std::runtime_error&) {
        return true;
    }
    return false;
}

int main() {
    const Orbit eros{20000433,          2461200.5,         .2228779627700761, 1.458243716760167,
                     10.82854410314273, 304.2679713350896, 178.9181319135911, 62.51145501986792};
    const Approach far{0.15, 2461300.5}, near{0.01, 2461300.5};

    auto s = Script::from_string(R"(
        function color(a)
            if a.dist > 0.05 then return nil end
            return 1, a.e, a.a / 10
        end
    )");
    CHECK(!s.color(eros, far));
    const auto c = s.color(eros, near);
    CHECK(c && c->r == 1.0f && c->g == float(eros.e) && c->b == float(eros.a / 10));

    // Integer ids reach Lua exactly.
    auto id = Script::from_string("function color(a) return a.spkid == 20000433 and 1 or 0, 0, 0 end");
    CHECK(id.color(eros, far)->r == 1.0f);

    // camera() is optional; when present it gets the frame number.
    CHECK(!s.has_camera());
    auto cam = Script::from_string("function color(a) return 1, 1, 1 end\n"
                                   "function camera(f) return f, -f, 2 end");
    CHECK(cam.has_camera());
    const Camera k = cam.camera(10);
    CHECK(k.rotate_x == 10.0f && k.rotate_y == -10.0f && k.distance == 2.0f);
    CHECK(color_throws("function color(a) return 1, 1, 1 end\n"
                       "function camera(f) return 'up' end",
                       Orbit{}, Approach{}) == false);  // color() itself is fine

    CHECK(load_throws("function color(a"));  // syntax error
    CHECK(load_throws("x = 1"));             // no color()
    CHECK(color_throws("function color(a) return 'red' end", eros, far));
    CHECK(color_throws("function color(a) error('boom') end", eros, far));

    return report();
}
