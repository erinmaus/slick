local slick = require("slick")
local test = require("test.common.test")
local util = require("test.common.util")

test("transforms should work as expected", function(t)
    local t1 = slick.newTransform(200, 500, math.pi / 2, 2, 2, 8, 8)
    local t2 = love.math.newTransform(200, 500, math.pi / 2, 2, 2, 8, 8)

    local x1, y1 = t1:transformPoint(0, 0)
    local x2, y2 = t2:transformPoint(0, 0)
    assert(util.equalish(x1, x2) and util.equalish(y1, y2), "transform mismatch")

    local x3, y3 = t1:inverseTransformPoint(200, 500)
    local x4, y4 = t2:inverseTransformPoint(200, 500)
    assert(util.equalish(x3, x4) and util.equalish(y3, y4), "transform mismatch")
end)
