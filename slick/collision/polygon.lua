local commonShape = require("slick.collision.commonShape")
local transform = require("slick.geometry.transform")

--- @class slick.collision.polygon: slick.collision.commonShape
local polygon = setmetatable({}, { __index = commonShape })
local metatable = { __index = polygon }

--- @param entity slick.entity | slick.cache
--- @param x1 number?
--- @param y1 number?
--- @param x2 number?
--- @param y2 number?
--- @param x3 number?
--- @param y3 number?
--- @param ... number
--- @return slick.collision.polygon
function polygon.new(entity, x1, y1, x2, y2, x3, y3, ...)
    local result = setmetatable(commonShape.new(entity), metatable)
    --- @cast result slick.collision.polygon    

    if x1 and y1 and x2 and y2 and x3 and y3 then
        result:init(x1, y1, x2, y2, x3, y3, ...)
    end

    return result
end

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @param x3 number
--- @param y3 number
--- @param ... number
function polygon:init(x1, y1, x2, y2, x3, y3, ...)
    commonShape.init(self)

    self:addPoints(x1, y1, x2, y2, x3, y3, ...)
    self:buildNormals()
    self:transform(transform.IDENTITY)

    assert(self.vertexCount >= 3, "polygon must have at least 3 points")
    assert(self.vertexCount == self.normalCount, "polygon must have as many normals as vertices")
end

return polygon
