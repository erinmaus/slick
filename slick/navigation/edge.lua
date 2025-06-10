--- @class slick.navigation.edge
--- @field a slick.navigation.vertex
--- @field b slick.navigation.vertex
--- @field min number
--- @field max number
local edge = {}
local metatable = { __index = edge }

--- @param a slick.navigation.vertex
--- @param b slick.navigation.vertex
--- @param interior boolean?
--- @param exterior boolean?
--- @return slick.navigation.edge
function edge.new(a, b, interior, exterior)
    return setmetatable({
        a = a,
        b = b,
        min = math.min(a.index, b.index),
        max = math.max(a.index, b.index),
        interior = not not interior,
        exterior = not not exterior
    }, metatable)
end

--- @param other slick.navigation.edge
--- @return boolean
function edge:same(other)
    return self == other or (self.min == other.min and self.max == other.max)
end

--- @param a slick.navigation.edge
--- @param b slick.navigation.edge
--- @return -1 | 0 | 1
function edge.compare(a, b)
    if a.min == b.min then
        return a.max - b.max
    else
        return a.min - b.min
    end
end

--- @param a slick.navigation.edge
--- @param b slick.navigation.edge
--- @return boolean
function edge.less(a, b)
    return edge.compare(a, b) < 0
end

return edge
