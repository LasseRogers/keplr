#pragma once
#include <cstdint>
#include <istream>
#include <vector>

// Osculating Keplerian elements as served by JPL SBDB: angles in degrees, epoch in JD (TDB).
struct Orbit {
    std::int64_t spkid;
    double epoch, e, a, i, om, w, ma;
};

// Parses the CSV written by scripts/fetch_sbdb.py; throws std::runtime_error on malformed input.
std::vector<Orbit> load_orbits(std::istream& in);
