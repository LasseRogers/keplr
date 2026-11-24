-- Red for asteroids passing within 0.05 AU of Earth in the next decade, the distance NASA uses
-- to call an asteroid potentially hazardous; dim gray for the rest.
function color(a)
  if a.dist < 0.05 then
    return 1.0, 0.2, 0.2
  end
  return 0.5, 0.5, 0.5
end
