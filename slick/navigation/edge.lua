--- @class slick.navigation.edge
--- @field a slick.navigation.vertex
--- @field b slick.navigation.vertex
--- @field min number
--- @field max number
local edge = {}
local metatable = { __index = edge }

--- @param a slick.navigation.vertex
--- @param b slick.navigation.vertex
--- @return slick.navigation.edge
function edge.new(a, b)
    return setmetatable({
        a = a,
        b = b,
        min = math.min(a.index, b.index),
        max = math.max(a.index, b.index),
    }, metatable)
end

--- @param other slick.navigation.edge
--- @return boolean
function edge:same(other)
    return self == other or (self.min == other.min and self.max == other.max)
end

return edge
