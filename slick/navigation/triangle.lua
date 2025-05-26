local point = require "slick.geometry.point"
local rectangle = require "slick.geometry.rectangle"

--- @class slick.navigation.triangle
--- @field triangle slick.navigation.vertex[]
--- @field vertices table<number, slick.navigation.vertex>
--- @field bounds slick.geometry.rectangle
--- @field centroid slick.geometry.point
--- @field index number
local triangle = {}
local metatable = { __index = triangle }

--- @param a slick.navigation.vertex
--- @param b slick.navigation.vertex
--- @param c slick.navigation.vertex
--- @param index number
function triangle.new(a, b, c, index)
    local self = setmetatable({
        triangle = { a, b, c },
        vertices = {
            [a.index] = a,
            [b.index] = b,
            [c.index] = c
        },
        centroid = point.new((a.point.x + b.point.x + c.point.x) / 3, (a.point.y + b.point.y + c.point.y) / 3),
        bounds = rectangle.new(a.point.x, a.point.y),
        index = index
    }, metatable)

    for i = 2, #self.triangle do
        local p = self.triangle[i].point
        self.bounds:expand(p.x, p.y)
    end

    return self
end

return triangle
