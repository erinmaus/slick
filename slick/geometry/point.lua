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

function point.new()
    return setmetatable({ x = 0, y = 0 }, metatable)
end

function point:init(x, y)
    self.x = x
    self.y = y
end

--- @alias slick.geometry.pointCompareFunc fun(a: slick.geometry.point, b: slick.geometry.point): slick.util.search.compareResult

--- @param E number
--- @return slick.geometry.pointCompareFunc
function point.compare(E)
    --- @param a slick.geometry.point
    --- @param b slick.geometry.point
    return function(a, b)
        if slickmath.lessThan(a.x, b.x, E) then
            return -1
        elseif slickmath.equal(a.x, b.x, E) then
            if slickmath.lessThan(a.y, b.y, E) then
                return -1
            elseif slickmath.equal(a.y, b.y, E) then
                return 0
            end
        end

        return 1
    end
end

--- @param other slick.geometry.point
--- @param E number
--- @return slick.geometry.point
function point:higher(other, E)
    if self:greaterThan(other, E) then
        return self
    end

    return other
end

--- @param other slick.geometry.point
--- @param E number
--- @return slick.geometry.point
function point:lower(other, E)
    if self:lessThan(other, E) then
        return self
    end

    return other
end

--- @param other slick.geometry.point
--- @param E number
--- @return boolean
function point:equal(other, E)
    return slickmath.equal(self.x, other.x, E) and slickmath.equal(self.y, other.y, E)
end

--- @param other slick.geometry.point
--- @param E number
--- @return boolean
function point:notEqual(other, E)
    return not point:equal(other, E)
end

--- @param other slick.geometry.point
--- @param E number
--- @return boolean
function point:greaterThan(other, E)
    return slickmath.greater(self.x, other.x, E) or 
           (slickmath.equal(self.x, other.x, E) and slickmath.greater(self.y, other.y, E))
end

--- @param other slick.geometry.point
--- @param E number
--- @return boolean
function point:greaterThanEqual(other, E)
    return self:greaterThan(other, E) or self:equal(other, E)
end

--- @param other slick.geometry.point
--- @param E number
--- @return boolean
function point:lessThan(other, E)
    return slickmath.less(self.x, other.x, E) or
           (slickmath.equal(self.x, other.x, E) and slickmath.less(self.y, other.y, E))
end

--- @param other slick.geometry.point
--- @param E number
--- @return boolean
function point:lessThanOrEqual(other, E)
    return self:lessThan(other, E) or self:equal(other, E)
end

--- @param segment slick.geometry.segment
--- @param E number
--- @return boolean left true if this point is to the left of segment, false otherwise
function point:left(segment, E)
    return slickmath.direction(segment.a, segment.b, self, E) < 0
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

return point
