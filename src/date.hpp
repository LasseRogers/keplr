#pragma once
#include <cmath>

struct Date {
    int year, month, day;
};

// Gregorian calendar date containing Julian Date jd (Meeus, Astronomical Algorithms, ch. 7).
// Assumes dates after the 1582 calendar reform, which is all this tool ever sees.
inline Date jd_to_date(double jd) {
    const double z = std::floor(jd + 0.5);
    const double alpha = std::floor((z - 1867216.25) / 36524.25);
    const double a = z + 1 + alpha - std::floor(alpha / 4);
    const double b = a + 1524;
    const double c = std::floor((b - 122.1) / 365.25);
    const double d = std::floor(365.25 * c);
    const double e = std::floor((b - d) / 30.6001);
    const int day = int(b - d - std::floor(30.6001 * e));
    const int month = e < 14 ? int(e) - 1 : int(e) - 13;
    const int year = month > 2 ? int(c) - 4716 : int(c) - 4715;
    return {year, month, day};
}
