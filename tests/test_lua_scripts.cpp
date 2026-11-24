#include "script.hpp"
#include "check.hpp"

#include <cstdio>
#include <filesystem>
#include <stdexcept>
#include <string>

static bool in_unit(const Color& c) {
    return c.r >= 0 && c.r <= 1 && c.g >= 0 && c.g <= 1 && c.b >= 0 && c.b <= 1;
}

static bool same(const Color& x, const Color& y) {
    return x.r == y.r && x.g == y.g && x.b == y.b;
}

int main() {
    // One of each NEO group: perihelion/aphelion put them unambiguously in their class.
    const Orbit atira{1, 2461200.5, 0.3, 0.7, 5.0, 10.0, 20.0, 30.0};   // Q = 0.91
    const Orbit aten{2, 2461200.5, 0.2, 0.9, 5.0, 10.0, 20.0, 30.0};    // Q = 1.08
    const Orbit apollo{3, 2461200.5, 0.6, 1.8, 3.0, 40.0, 50.0, 60.0};  // q = 0.72
    const Orbit amor{20000433, 2461200.5, .2229, 1.4582, 10.83, 304.27, 178.92, 62.51};  // Eros
    const Orbit samples[] = {atira, aten, apollo, amor};
    const Approach approaches[] = {{0.3, 2461300.5}, {0.005, 2461300.5}};

    // Every shipped script loads and returns valid colours for every sample.
    int scripts = 0;
    for (const auto& entry : std::filesystem::directory_iterator(KEPLR_LUA_DIR)) {
        if (entry.path().extension() != ".lua") continue;
        ++scripts;
        try {
            auto s = Script::from_file(entry.path().string());
            for (const Orbit& o : samples)
                for (const Approach& a : approaches)
                    if (const auto c = s.color(o, a)) CHECK(in_unit(*c));
            if (s.has_camera()) {
                s.camera(0);
                s.camera(100000);  // well past any tour's end
            }
        } catch (const std::runtime_error& e) {
            std::fprintf(stderr, "%s\n", e.what());
            CHECK(false);
        }
    }
    CHECK(scripts >= 3);

    // groups.lua tells the four classes apart.
    auto groups = Script::from_file(std::string(KEPLR_LUA_DIR) + "/groups.lua");
    Color c[4];
    for (int k = 0; k < 4; ++k) c[k] = *groups.color(samples[k], approaches[0]);
    for (int i = 0; i < 4; ++i)
        for (int j = i + 1; j < 4; ++j) CHECK(!same(c[i], c[j]));

    return report();
}
