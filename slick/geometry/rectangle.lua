local point = require("slick.geometry.point")
local slickmath = require("slick.util.slickmath")

--- @class slick.geometry.rectangle
--- @field topLeft slick.geometry.point
--- @field topRight slick.geometry.point
local rectangle = {}
local metatable = {
    __index = rectangle
}

--- @param x1 number?
--- @param y1 number?
--- @param x2 number?
--- @param y2 number?
--- @return slick.geometry.rectangle
function rectangle.new(x1, y1, x2, y2)
    local result = setmetatable({}, metatable)
    result:init(x1, y1, x2, y2)

    return result
end

--- @param x1 number?
--- @param y1 number?
--- @param x2 number?
--- @param y2 number?
function rectangle:init(x1, y1, x2, y2)
    x1 = x1 or 0
    x2 = x2 or x1
    y1 = y1 or 0
    y2 = y2 or y1 

    self.topLeft = point.new(math.min(x1, x2), math.min(y1, y2))
    self.bottomRight = point.new(math.max(x1, x2), math.max(y1, y2))
end

function rectangle:left()
    return self.topLeft.x
end

function rectangle:right()
    return self.bottomRight.x
end

function rectangle:top()
    return self.topLeft.y
end

function rectangle:bottom()
    return self.bottomRight.y
end

--- @param other slick.geometry.rectangle
--- @return boolean
function rectangle:overlaps(other)
    return self:left() <= other:right() and self:right() >= other:left() and
           self:top() <= other:bottom() and self:bottom() >= other:top()
end

return rectangle
