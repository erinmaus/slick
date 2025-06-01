--- @class slick.geometry.triangulation.edge
--- @field a number
--- @field b number
--- @field min number
--- @field max number
local edge = {}
local metatable = { __index = edge }

--- @param a number?
--- @param b number?
--- @return slick.geometry.triangulation.edge
function edge.new(a, b)
    return setmetatable({
        a = a,
        b = b,
        min = a and b and math.min(a, b),
        max = a and b and math.max(a, b),
    }, metatable)
end

--- @param a slick.geometry.triangulation.edge
--- @param b slick.geometry.triangulation.edge
function edge.less(a, b)
    if a.min == b.min then
        return a.max < b.max
    end

    return a.min < b.min
end

--- @param a slick.geometry.triangulation.edge
--- @param b slick.geometry.triangulation.edge
--- @return -1 | 0 | 1
function edge.compare(a, b)
    local min = a.min - b.min
    if min ~= 0 then
        return min
    end

    return a.max - b.max
end

--- @param a number
--- @param b number
function edge:init(a, b)
    self.a = a
    self.b = b
    self.min = math.min(a, b)
    self.max = math.max(a, b)
end

return edge
