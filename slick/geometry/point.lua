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

function point:init(x, y)
    self.x = x
    self.y = y
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @return slick.util.search.compareResult
function point.compare(a, b)
    if slickmath.less(a.x, b.x) then
        return -1
    elseif slickmath.equal(a.x, b.x) then
        if slickmath.less(a.y, b.y) then
            return -1
        elseif slickmath.equal(a.y, b.y) then
            return 0
        end
    end

    return 1
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
    return slickmath.equal(self.x, other.x) and slickmath.equal(self.y, other.y)
end

--- @param other slick.geometry.point
--- @return boolean
function point:notEqual(other)
    return not point:equal(other)
end

--- @param other slick.geometry.point
--- @return boolean
function point:greaterThan(other)
    return slickmath.greater(self.x, other.x) or 
           (slickmath.equal(self.x, other.x) and slickmath.greater(self.y, other.y))
end

--- @param other slick.geometry.point
--- @return boolean
function point:greaterThanEqual(other)
    return self:greaterThan(other) or self:equal(other)
end

--- @param other slick.geometry.point
--- @return boolean
function point:lessThan(other)
    return slickmath.less(self.x, other.x) or
           (slickmath.equal(self.x, other.x) and slickmath.less(self.y, other.y))
end

--- @param other slick.geometry.point
--- @return boolean
function point:lessThanOrEqual(other)
    return self:lessThan(other) or self:equal(other)
end

--- @param segment slick.geometry.segment
--- @return boolean left true if this point is to the left of segment, false otherwise
function point:left(segment)
    return slickmath.direction(segment.a, segment.b, self) < 0
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
function point:length()
    return math.sqrt(self.x ^ 2 + self.y ^ 2)
end

--- @param other slick.geometry.point
--- @return number
function point:distance(other)
    return math.sqrt((self.x - other.x) ^ 2 + (self.x - other.x) ^ 2)
end

--- Warning does not check for 0 length.
--- @param result slick.geometry.point
function point:normalize(result)
    local length = self:length()

    result.x = self.x / length
    result.y = self.y / length
end

return point
