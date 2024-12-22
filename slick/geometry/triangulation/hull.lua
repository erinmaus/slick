local slickmath = require("slick.util.slickmath")
local slicktable = require("slick.util.slicktable")

--- @class slick.geometry.triangulation.hull
--- @field a slick.geometry.point
--- @field b slick.geometry.point
--- @field lowerPoints number[]
--- @field higherPoints number[]
--- @field index number
local hull = {}
local metatable = { __index = hull }

--- @return slick.geometry.triangulation.hull
function hull.new()
    return setmetatable({
        higherPoints = {},
        lowerPoints = {}
    }, metatable)
end

--- @param hull slick.geometry.triangulation.hull
--- @param point slick.geometry.point
--- @return slick.util.search.compareResult
function hull.point(hull, point)
    return slickmath.direction(hull.a, hull.b, point)
end

--- @param hull slick.geometry.triangulation.hull
--- @param sweep slick.geometry.triangulation.sweep
--- @return slick.util.search.compareResult
function hull.sweep(hull, sweep)
    local direction

    if hull.a.x < sweep.data.a.x then
        direction = slickmath.direction(hull.a, hull.b, sweep.data.a)
    else
        direction = slickmath.direction(sweep.data.b, sweep.data.a, hull.a)
    end

    if direction ~= 0 then
        return direction
    end

    if sweep.data.b.x < hull.b.x then
        direction = slickmath.direction(hull.a, hull.b, sweep.data.b)
    else
        direction = slickmath.direction(sweep.data.b, sweep.data.a, hull.b)
    end

    if direction ~= 0 then
        return direction
    end

    return hull.index - sweep.index
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param index number
function hull:init(a, b, index)
    self.a = a
    self.b = b
    self.index = index

    slicktable.clear(self.higherPoints)
    slicktable.clear(self.lowerPoints)
end

return hull
