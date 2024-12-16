local seidel = require("slick.geometry.seidel.seidel")

local s = seidel.new({ rng = love.math.newRandomGenerator(0) })

-- shape 1
s:addPoint(337, 182)
s:addPoint(173, 518)
s:addPoint(173, 518)
s:addPoint(453, 695)
s:addPoint(684, 470)
s:addPoint(589, 208)

-- shape 2
s:addPoint(365, 261)
s:addPoint(278, 452)
s:addPoint(407, 559)
s:addPoint(515, 332)

s:generate("even-odd")
