local entity = require("slick.entity")
local point = require("slick.geometry.point")
local transform = require("slick.geometry.transform")
local rectangle = require("slick.geometry.rectangle")

--- @class slick.collision.circle: slick.collision.commonShape
--- @field entity slick.entity?
--- @field count number
--- @field vertices slick.geometry.point[]
--- @field normals slick.geometry.point[]
--- @field radius number
--- @field bounds slick.geometry.rectangle
--- @field center slick.geometry.point
--- @field private preTransformedCenter slick.geometry.point
--- @field private preTransformedRadius number
local circle = {}
local metatable = { __index = circle }

--- @param e slick.entity?
--- @param x number
--- @param y number
--- @param radius number
--- @return slick.collision.circle
function circle.new(e, x, y, radius)
    local result = setmetatable({
        entity = e or entity.new(),
        count = 0,
        vertices = {},
        normals = {},
        center = point.new(),
        radius = 0,
        bounds = rectangle.new(),
        preTransformedCenter = point.new(),
        preTransformedRadius = 0
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
    self.center:init(transform:transformPoint(self.preTransformedCenter.x, self.preTransformedCenter.y))
    self.bounds:init(self.center.x - self.radius, self.center.y - self.radius, self.center.x + self.radius, self.center.y + self.radius)
end

--- @param query slick.collision.shapeCollisionResolutionQuery
function circle:getAxes(query)
    -- Nothing.
end

local _cachedOffsetCircleCenter = point.new()

--- @param query slick.collision.shapeCollisionResolutionQuery
--- @param axis slick.geometry.point
--- @param interval slick.collision.interval
function circle:project(query, axis, interval, offset)
    _cachedOffsetCircleCenter:init(self.center.x, self.center.y)
    if offset then
        _cachedOffsetCircleCenter:add(offset, _cachedOffsetCircleCenter)
    end

    local d = _cachedOffsetCircleCenter:dot(axis)
    interval:set(d - self.radius, d + self.radius)
end

--- @param p slick.geometry.point
function circle:distance(p)
    return math.max(0, p:distance(self.center) - self.radius)
end

--- @param p slick.geometry.point
--- @return boolean
function circle:inside(p)
    return p:distance(self.center) <= self.radius
end

local _cachedRaycastDirection = point.new()
local _cachedRaycastProjection = point.new()

--- @param r slick.geometry.ray
--- @param normal slick.geometry.point?
--- @return boolean, number?, number?
function circle:raycast(r, normal)
    self.center:direction(r.origin, _cachedRaycastDirection)
    local b = _cachedRaycastDirection:dot(r.direction)
    local c = _cachedRaycastDirection:dot(_cachedRaycastDirection) - self.radius ^ 2

    if not (c > 0 and b > 0) then
        local discriminant = b * b - c
        if discriminant >= 0 then
            local t1 = -b - math.sqrt(discriminant)
            local t2 = -b + math.sqrt(discriminant)

            local t
            if t1 >= 0 then
                t = t1
            elseif t2 >= 0 then
                t = t2
            end

            if t then
                r:project(t, _cachedRaycastProjection)
                if normal then
                    self.center:direction(_cachedRaycastProjection, normal)
                    normal:normalize(normal)
                end

                return true, _cachedRaycastProjection.x, _cachedRaycastProjection.y
            end
        end
    end

    return false, nil, nil
end

return circle
