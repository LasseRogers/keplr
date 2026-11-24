-- Only asteroids passing within 0.01 AU of Earth in the next decade (about 1.5 million km,
-- four lunar distances); the rest are hidden and never reach the GPU.
function color(a)
  if a.dist >= 0.01 then
    return nil
  end
  return 1.0, 0.3, 0.3
end
