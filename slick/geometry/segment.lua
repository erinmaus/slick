local point = require("slick.geometry.point")

--- @class slick.geometry.segment
--- @field a slick.geometry.point
--- @field b slick.geometry.point
local segment = {}
local metatable = { __index = segment }

--- @param a slick.geometry.point?
--- @param b slick.geometry.point?
--- @return slick.geometry.segment
function segment.new(a, b)
    return setmetatable({
        a = point.new(a and a.x, a and a.y),
        b = point.new(b and b.x, b and b.y),
    }, metatable)
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
function segment:init(a, b)
    self.a:init(a.x, a.y)
    self.b:init(b.x, b.y)
end

--- @return number
function segment:left()
    return math.min(self.a.x, self.b.x)
end

--- @return number
function segment:right()
    return math.max(self.a.x, self.b.x)
end

--- @return number
function segment:top()
    return math.min(self.a.y, self.b.y)
end

--- @return number
function segment:bottom()
    return math.max(self.a.y, self.b.y)
end

local _cachedProjectionBMinusA = point.new()
local _cachedProjectionPMinusA = point.new()
local _cachedProjectionPProjectedAB = point.new()

--- @param p slick.geometry.point
--- @param result slick.geometry.point
function segment:project(p, result)
    local distanceSquared = self.a:distanceSquared(self.b)
    if distanceSquared == 0 then
        result:init(self.a.x, self.a.y)
        return
    end
    
    p:sub(self.a, _cachedProjectionPMinusA)
    self.b:sub(self.a, _cachedProjectionBMinusA)
    
    local t = math.max(0, math.min(1, _cachedProjectionPMinusA:dot(_cachedProjectionBMinusA) / distanceSquared))
    
    _cachedProjectionBMinusA:multiplyScalar(t, result)
    self.a:add(result, result)
end

local _cachedDistancePProjectedAB = point.new()
--- @param p slick.geometry.point
function segment:distanceSquared(p)
    self:project(p, _cachedDistancePProjectedAB)
    return _cachedDistancePProjectedAB:distanceSquared(p)
end

--- @param p slick.geometry.point
function segment:distance(p)
    return math.sqrt(self:distanceSquared(p))
end

--- @alias slick.geometry.segmentCompareFunc fun(a: slick.geometry.segment, b: slick.geometry.segment): slick.util.search.compareResult

--- @param a slick.geometry.segment
--- @param b slick.geometry.segment
--- @return slick.util.search.compareResult
function segment.compare(a, b)
    local aMinPoint, aMaxPoint
    if a.b:lessThan(a.a) then
        aMinPoint = a.b
        aMaxPoint = a.a
    else
        aMinPoint = a.a
        aMaxPoint = a.b
    end

    local bMinPoint, bMaxPoint
    if b.b:lessThan(b.a) then
        bMinPoint = b.b
        bMaxPoint = b.a
    else
        bMinPoint = b.a
        bMaxPoint = b.b
    end

    local s = point.compare(aMinPoint, bMinPoint)
    if s ~= 0 then
        return s
    end

    return point.compare(aMaxPoint, bMaxPoint)
end

--- @param a slick.geometry.segment
--- @param b slick.geometry.segment
--- @return boolean
function segment.less(a, b)
    return segment.compare(a, b) < 0
end

--- @param other slick.geometry.segment
--- @return boolean
function segment:lessThan(other)
    return self.a:lessThan(other.a) or
           (self.a:equal(other.a) and self.b:lessThan(other.b))
end

--- @param other slick.geometry.segment
--- @return boolean
function segment:overlap(other)
    local selfLeft = math.min(self.a.x, self.b.x)
    local selfRight = math.max(self.a.x, self.b.x)
    local selfTop = math.min(self.a.y, self.b.y)
    local selfBottom = math.max(self.a.y, self.b.y)

    local otherLeft = math.min(other.a.x, other.b.x)
    local otherRight = math.max(other.a.x, other.b.x)
    local otherTop = math.min(other.a.y, other.b.y)
    local otherBottom = math.max(other.a.y, other.b.y)

    return (selfLeft <= otherRight and selfRight >= otherLeft) and
           (selfTop <= otherBottom and selfBottom >= otherTop)
end

return segment
