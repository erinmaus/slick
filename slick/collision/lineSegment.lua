local commonShape = require("slick.collision.commonShape")
local point = require("slick.geometry.point")
local segment = require("slick.geometry.segment")
local transform = require("slick.geometry.transform")
local slickmath = require("slick.util.slickmath")

--- @class slick.collision.lineSegment: slick.collision.commonShape
--- @field segment slick.geometry.segment
--- @field private preTransformedSegment slick.geometry.segment
local lineSegment = setmetatable({}, { __index = commonShape })
local metatable = { __index = lineSegment }

--- @param entity slick.entity?
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return slick.collision.lineSegment
function lineSegment.new(entity, x1, y1, x2, y2)
    local result = setmetatable(commonShape.new(entity), metatable)

    result.segment = segment.new()
    result.preTransformedSegment = segment.new()

    --- @cast result slick.collision.lineSegment
    result:init(x1, y1, x2, y2)
    return result
end

local _cachedInitNormal = point.new()

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
function lineSegment:init(x1, y1, x2, y2)
    commonShape.init(self)

    self.preTransformedSegment.a:init(x1, y1)
    self.preTransformedSegment.b:init(x2, y2)

    if not self.preTransformedSegment.a:lessThanOrEqual(self.preTransformedSegment.b) then
        self.preTransformedSegment.a, self.preTransformedSegment.b = self.preTransformedSegment.b, self.preTransformedSegment.a
    end

    self:addPoints(
        self.preTransformedSegment.a.x,
        self.preTransformedSegment.a.y,
        self.preTransformedSegment.b.x,
        self.preTransformedSegment.b.y)
    
    self.preTransformedSegment.a:direction(self.preTransformedSegment.b, _cachedInitNormal)
    _cachedInitNormal:normalize(_cachedInitNormal)

    self:addNormal(_cachedInitNormal.x, _cachedInitNormal.y)

    _cachedInitNormal:left(_cachedInitNormal)
    self:addNormal(_cachedInitNormal.x, _cachedInitNormal.y)

    self:transform(transform.IDENTITY)

    assert(self.vertexCount == 2, "line segment must have 2 points")
    assert(self.normalCount == 2, "line segment must have 2 normals")
end

--- @param transform slick.geometry.transform
function lineSegment:transform(transform)
    commonShape.transform(self, transform)

    self.segment.a:init(transform:transformPoint(self.preTransformedSegment.a.x, self.preTransformedSegment.a.y))
    self.segment.b:init(transform:transformPoint(self.preTransformedSegment.b.x, self.preTransformedSegment.b.y))
end

--- @param p slick.geometry.point
--- @return boolean
function lineSegment:inside(p)
    local intersection, x, y = slickmath.intersection(self.vertices[1], self.vertices[2], p, p)
    return intersection and not (x and y)
end

--- @param p slick.geometry.point
--- @return number
function lineSegment:distance(p)
    return self.segment:distance(p)
end

--- @param r slick.geometry.ray
--- @return boolean, number?, number?
function lineSegment:raycast(r)
    local h, x, y = r:hitSegment(self.segment)
    return h, x, y
end

return lineSegment
