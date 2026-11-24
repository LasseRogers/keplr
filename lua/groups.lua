-- The four classic near-Earth asteroid groups, from perihelion q = a(1 - e) and
-- aphelion Q = a(1 + e) in AU, using NASA CNEOS's boundaries.
local function group(a)
  local q, Q = a.a * (1 - a.e), a.a * (1 + a.e)
  if a.a < 1.0 then
    return Q < 0.983 and "atira" or "aten"
  end
  return q < 1.017 and "apollo" or "amor"
end

local palette = {
  atira = { 1.0, 0.8, 0.2 }, -- entirely inside Earth's orbit
  aten = { 1.0, 0.4, 0.2 }, -- mostly inside, crossing it
  apollo = { 0.3, 0.7, 1.0 }, -- mostly outside, crossing it
  amor = { 0.4, 0.9, 0.4 }, -- approach from outside without crossing
}

function color(a)
  return table.unpack(palette[group(a)])
end
