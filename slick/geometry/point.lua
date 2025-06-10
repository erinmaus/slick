local slickmath = require("slick.util.slickmath")

--- @class slick.geometry.point
--- @field x number
--- @field y number
local point = {}
local metatable = {
    __index = point,
    __tostring = function(self)
        return string.format("slick.geometry.point (x = %.2f, y = %.2f)", self.x, self.y)            
    end
}


--- @param x number?
--- @param y number?
--- @return slick.geometry.point
function point.new(x, y)
    return setmetatable({ x = x or 0, y = y or 0 }, metatable)
end

--- @param x number
--- @param y number
function point:init(x, y)
    self.x = x
    self.y = y
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @return slick.util.search.compareResult
function point.compare(a, b, E)
    local result = slickmath.sign(a.x - b.x, E or slickmath.EPSILON)
    if result ~= 0 then
        return result
    end

    return slickmath.sign(a.y - b.y, E or slickmath.EPSILON)
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @return boolean
function point.less(a, b)
    return point.compare(a, b) < 0
end

--- @param other slick.geometry.point
--- @return slick.geometry.point
function point:higher(other)
    if self:greaterThan(other) then
        return self
    end

    return other
end

--- @param other slick.geometry.point
--- @return slick.geometry.point
function point:lower(other)
    if self:lessThan(other) then
        return self
    end

    return other
end

--- @param other slick.geometry.point
--- @return boolean
function point:equal(other)
    return self.x == other.x and self.y == other.y
end

--- @param other slick.geometry.point
--- @return boolean
function point:notEqual(other)
    return not point:equal(other)
end

--- @param other slick.geometry.point
--- @return boolean
function point:greaterThan(other)
    return self.x > other.x or (self.x == other.x and self.y > other.y)
end

--- @param other slick.geometry.point
--- @return boolean
function point:greaterThanEqual(other)
    return self:greaterThan(other) or self:equal(other)
end

--- @param other slick.geometry.point
--- @return boolean
function point:lessThan(other)
    return self.x < other.x or (self.x == other.x and self.y < other.y)
end

--- @param other slick.geometry.point
--- @return boolean
function point:lessThanOrEqual(other)
    return self:lessThan(other) or self:equal(other)
end

--- @param other slick.geometry.point
--- @param result slick.geometry.point
function point:direction(other, result)
    result:init(other.x - self.x, other.y - self.y)
end

--- @param other slick.geometry.point
function point:left(other)
    other:init(self.y, -self.x)
end

--- @param other slick.geometry.point
function point:right(other)
    other:init(-self.y, self.x)
end

--- @param other slick.geometry.point
--- @return number
function point:dot(other)
    return self.x * other.x + self.y * other.y
end

--- @param other slick.geometry.point
--- @param result slick.geometry.point
function point:add(other, result)
    result.x = self.x + other.x
    result.y = self.y + other.y
end

--- @param other number
--- @param result slick.geometry.point
function point:addScalar(other, result)
    result.x = self.x + other
    result.y = self.y + other
end

--- @param other slick.geometry.point
--- @param result slick.geometry.point
function point:sub(other, result)
    result.x = self.x - other.x
    result.y = self.y - other.y
end

--- @param other number
--- @param result slick.geometry.point
function point:subScalar(other, result)
    result.x = self.x - other
    result.y = self.y - other
end

--- @param other slick.geometry.point
--- @param result slick.geometry.point
function point:multiply(other, result)
    result.x = self.x * other.x
    result.y = self.y * other.y
end

--- @param other number
--- @param result slick.geometry.point
function point:multiplyScalar(other, result)
    result.x = self.x * other
    result.y = self.y * other
end

--- @param other slick.geometry.point
--- @param result slick.geometry.point
function point:divide(other, result)
    result.x = self.x / other.x
    result.y = self.y / other.y
end

--- @param other number
--- @param result slick.geometry.point
function point:divideScalar(other, result)
    result.x = self.x / other
    result.y = self.y / other
end

--- @return number
function point:lengthSquared()
    return self.x ^ 2 + self.y ^ 2
end

--- @return number
function point:length()
    return math.sqrt(self:lengthSquared())
end

--- @param other slick.geometry.point
--- @return number
function point:distanceSquared(other)
    return (self.x - other.x) ^ 2 + (self.y - other.y) ^ 2
end

--- @param other slick.geometry.point
--- @return number
function point:distance(other)
    return math.sqrt(self:distanceSquared(other))
end

--- @param result slick.geometry.point
function point:normalize(result)
    local length = self:length()
    if length > 0 then
        result.x = self.x / length
        result.y = self.y / length
    end
end

--- @param other slick.geometry.point
--- @param E number
function point:round(other, E)
    other.x = self.x
    if other.x > -E and other.x < E then
        other.x = 0
    end

    other.y = self.y
    if other.y > -E and other.y < E then
        other.y = 0
    end
end

--- @param result slick.geometry.point
function point:negate(result)
    result.x = -self.x
    result.y = -self.y
end

return point
