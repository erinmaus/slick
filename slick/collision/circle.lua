local point = require("slick.geometry.point")
local transform = require("slick.geometry.transform")

--- @class slick.collision.circle
--- @field entity slick.entity
--- @field count number
--- @field vertices slick.geometry.point[]
--- @field normals slick.geometry.point[]
--- @field radius number
--- @field center slick.geometry.point
--- @field private preTransformedCenter slick.geometry.point
--- @field private preTransformedRadius number
local circle = {}
local metatable = { __index = circle }

--- @param entity slick.entity
--- @param x number
--- @param y number
--- @param radius number
--- @return slick.collision.circle
function circle.new(entity, x, y, radius)
    local result = setmetatable({
        entity = entity,
        count = 0,
        vertices = {},
        normals = {},
        number = radius,
        center = point.new()
    }, metatable)

    result:init(x, y, radius)

    return result
end

--- @param x number
--- @param y number
--- @param radius number
function circle:init(x, y, radius)
    self.count = 0
    
    self.preTransformedCenter:init(x, y)
    self.preTransformedRadius = radius

    self:transform(transform.IDENTITY)
end

--- @param transform slick.geometry.transform
function circle:transform(transform)
    self.radius = self.preTransformedRadius * math.min(transform.scaleX, transform.scaleY)
    self.center:init(transform:transformPoint(self.center.x, self.center.y))
end

--- @param query slick.collision.shapeCollisionResolutionQuery
function circle:getAxes(query)
    -- Nothing.
end

--- @param query slick.collision.shapeCollisionResolutionQuery
--- @param axis slick.geometry.point
--- @param interval slick.collision.interval
function circle:project(query, axis, interval)
    local d = self.center:dot(axis)
    interval:set(d - self.radius, d + self.radius)
end

return circle