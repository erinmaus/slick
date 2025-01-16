local point = require("slick.geometry.point")
local slickmath = require("slick.util.slickmath")

--- @class slick.geometry.rectangle
--- @field topLeft slick.geometry.point
--- @field bottomRight slick.geometry.point
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
    local result = setmetatable({ topLeft = point.new(), bottomRight = point.new() }, metatable)
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

    self.topLeft:init(math.min(x1, x2), math.min(y1, y2))
    self.bottomRight:init(math.max(x1, x2), math.max(y1, y2))
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

function rectangle:width()
    return self:right() - self:left()
end

function rectangle:height()
    return self:bottom() - self:top()
end

--- @param x number
--- @param y number
function rectangle:expand(x, y)
    self.topLeft.x = math.min(self.topLeft.x, x)
    self.topLeft.y = math.min(self.topLeft.y, y)
    self.bottomRight.x = math.max(self.bottomRight.x, x)
    self.bottomRight.y = math.max(self.bottomRight.y, y)
end

---@param x number
---@param y number
function rectangle:move(x, y)
    self.topLeft.x = self.topLeft.x + x
    self.topLeft.y = self.topLeft.y + y
    self.bottomRight.x = self.bottomRight.x + x
    self.bottomRight.y = self.bottomRight.y + y
end

--- @param x number
--- @param y number
function rectangle:sweep(x, y)
    self:expand(x - self:width(), y - self:height())
    self:expand(x + self:width(), y + self:height())
end

--- @param other slick.geometry.rectangle
--- @return boolean
function rectangle:overlaps(other)
    return self:left() <= other:right() and self:right() >= other:left() and
           self:top() <= other:bottom() and self:bottom() >= other:top()
end

--- @param p slick.geometry.point
--- @param E number?
--- @return boolean
function rectangle:inside(p, E)
    E = E or 0
    return slickmath.withinRange(p.x, self:left(), self:right(), E) and slickmath.withinRange(p.y, self:top(), self:bottom(), E)
end

return rectangle
