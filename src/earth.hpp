#pragma once
#include "orbit.hpp"

// Earth-Moon barycentre from JPL's "Keplerian Elements for Approximate Positions of the Major
// Planets" (Standish), Table 1, at J2000. The table's secular rates are dropped: the resulting
// drift reaches ~0.003 AU after a century, well below close-approach screening distances.
// Converted to SBDB's convention: w = long.peri - node, M = mean longitude - long.peri.
constexpr Orbit kEarth{3,           2451545.0,    0.01671123,   1.00000261,
                       -0.00001531, 0.0,          102.93768193, 100.46457166 - 102.93768193};
