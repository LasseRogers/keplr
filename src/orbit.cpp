#include "orbit.hpp"

#include <array>
#include <charconv>
#include <stdexcept>
#include <string>
#include <string_view>

namespace {

constexpr std::string_view kHeader = "spkid,epoch,e,a,i,om,w,ma";
constexpr int kFields = 8;

// from_chars over stod: no locale, no allocation, and it rejects trailing garbage.
template <class T>
T parse(std::string_view field, std::string_view line) {
    T value{};
    const char* end = field.data() + field.size();
    auto [ptr, ec] = std::from_chars(field.data(), end, value);
    if (ec != std::errc{} || ptr != end)
        throw std::runtime_error("bad field '" + std::string(field) + "' in: " + std::string(line));
    return value;
}

// Python's csv module writes CRLF by default; getline only strips the LF.
void chomp_cr(std::string& s) {
    if (!s.empty() && s.back() == '\r') s.pop_back();
}

}  // namespace

std::vector<Orbit> load_orbits(std::istream& in) {
    std::string line;
    if (std::getline(in, line)) chomp_cr(line);
    if (line != kHeader)
        throw std::runtime_error("unexpected header: " + line);

    std::vector<Orbit> orbits;
    while (std::getline(in, line)) {
        chomp_cr(line);
        if (line.empty()) continue;

        std::array<std::string_view, kFields> f;
        std::string_view rest = line;
        for (int k = 0; k < kFields; ++k) {
            const auto comma = rest.find(',');
            const bool last = k == kFields - 1;
            if ((comma == std::string_view::npos) != last)
                throw std::runtime_error("expected 8 fields in: " + line);
            f[k] = rest.substr(0, comma);
            if (!last) rest.remove_prefix(comma + 1);
        }

        orbits.push_back({parse<std::int64_t>(f[0], line), parse<double>(f[1], line),
                          parse<double>(f[2], line), parse<double>(f[3], line),
                          parse<double>(f[4], line), parse<double>(f[5], line),
                          parse<double>(f[6], line), parse<double>(f[7], line)});
    }
    return orbits;
}
