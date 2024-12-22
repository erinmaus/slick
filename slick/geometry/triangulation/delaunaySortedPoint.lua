local point = require("slick.geometry.point")

--- @class slick.geometry.triangulation.delaunaySortedPoint
--- @field point slick.geometry.point
--- @field id number
--- @field newID number
local delaunaySortedPoint = {}
local metatable = { __index = delaunaySortedPoint }

--- @return slick.geometry.triangulation.delaunaySortedPoint
function delaunaySortedPoint.new()
    return setmetatable({
        id = 0,
        newID = 0,
        point = point.new()
    }, metatable)
end

--- @param s slick.geometry.triangulation.delaunaySortedPoint
--- @param p slick.geometry.point
--- @return slick.util.search.compareResult
function delaunaySortedPoint.comparePoint(s, p)
    return point.compare(s.point, p)
end

--- @param a slick.geometry.triangulation.delaunaySortedPoint
--- @param b slick.geometry.triangulation.delaunaySortedPoint
--- @return slick.util.search.compareResult
function delaunaySortedPoint.compare(a, b)
    return point.compare(a.point, b.point)
end

--- @param a slick.geometry.triangulation.delaunaySortedPoint
--- @param b slick.geometry.triangulation.delaunaySortedPoint
--- @return slick.util.search.compareResult
function delaunaySortedPoint.compareID(a, b)
    return a.id - b.id
end

--- @param a slick.geometry.triangulation.delaunaySortedPoint
--- @param b slick.geometry.triangulation.delaunaySortedPoint
--- @return boolean
function delaunaySortedPoint.less(a, b)
    return delaunaySortedPoint.compare(a, b) < 0
end

--- @param a slick.geometry.triangulation.delaunaySortedPoint
--- @param b slick.geometry.triangulation.delaunaySortedPoint
--- @return boolean
function delaunaySortedPoint.lessID(a, b)
    return delaunaySortedPoint.compareID(a, b) < 0
end

--- @param point slick.geometry.point
--- @param id number
function delaunaySortedPoint:init(point, id)
    self.id = id
    self.newID = 0
    self.point:init(point.x, point.y)
end

return delaunaySortedPoint
