-- A 3000-frame fly-by for recordings (about 30 s at 100 fps): from straight above the
-- ecliptic, tilt towards an edge-on view while closing in on Earth's orbit.
-- Colours as in hazard.lua.
function color(a)
  if a.dist < 0.05 then
    return 1.0, 0.2, 0.2
  end
  return 0.5, 0.5, 0.5
end

local frames = 3000

-- Smoothstep: eases in and out, clamped to [0, 1].
local function smooth(x)
  x = math.max(0, math.min(1, x))
  return x * x * (3 - 2 * x)
end

function camera(frame)
  local s = smooth(frame / frames)
  local tilt = -70 * s -- degrees away from top-down
  local distance = 6 - 3.5 * s -- AU
  return tilt, 0, distance
end
