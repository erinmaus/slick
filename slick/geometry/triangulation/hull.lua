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

--- @alias slick.geometry.triangulation.hullPointCompareFunc fun(hull: slick.geometry.triangulation.hull, point: slick.geometry.point): slick.util.search.compareResult
--- @alias slick.geometry.triangulation.hullSweepCompareFunc fun(hull: slick.geometry.triangulation.hull, sweep: slick.geometry.triangulation.sweep): slick.util.search.compareResult

--- @param E number
--- @return slick.geometry.triangulation.hullPointCompareFunc
function hull.point(E)
    return function(hull, point)
        return slickmath.direction(hull.a, hull.b, point, E)
    end
end

--- @param E number
--- @return slick.geometry.triangulation.hullSweepCompareFunc
function hull.sweep(E)
    return function(hull, sweep)
        local direction

        if slickmath.less(hull.a.x, sweep.data.a.x, E) then
            direction = slickmath.direction(hull.a, hull.b, sweep.data.a, E)
        else
            direction = slickmath.direction(sweep.data.b, sweep.data.a, hull.a, E)
        end

        if direction ~= 0 then
            return direction
        end

        if slickmath.less(sweep.data.b.x, hull.b.x, E) then
            direction = slickmath.direction(hull.a, hull.b, sweep.data.b, E)
        else
            direction = slickmath.direction(sweep.data.b, sweep.data.a, hull.b, E)
        end

        if direction ~= 0 then
            return direction
        end

        return hull.index - sweep.index
    end
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
