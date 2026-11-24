#pragma once
#include <cstdio>

// Each test binary is one translation unit, so a single inline counter suffices.
inline int failures = 0;

// Records failures instead of aborting, so one run reports every broken check.
#define CHECK(cond)                                                            \
    do {                                                                       \
        if (!(cond)) {                                                         \
            std::fprintf(stderr, "%s:%d: CHECK(%s)\n", __FILE__, __LINE__, #cond); \
            ++failures;                                                        \
        }                                                                      \
    } while (0)

// Exit code for main().
inline int report() {
    if (failures == 0) std::puts("ok");
    return failures == 0 ? 0 : 1;
}
