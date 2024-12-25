local circle = require "slick.collision.circle"
local interval = require "slick.collision.interval"
local point = require "slick.geometry.point"
local segment = require "slick.geometry.segment"
local util = require "slick.util"

--- @alias slick.collision.shapeCollisionResolutionQueryShape {
---     shape: slick.collision.shape?,
---     axesCount: number,
---     axes: slick.geometry.point[],
---     interval: slick.collision.interval,
--- }

--- @class slick.collision.shapeCollisionResolutionQuery
--- @field normal slick.geometry.point
--- @field depth number
--- @field collision boolean
--- @field firstTime number
--- @field lastTime number
--- @field private currentShape slick.collision.shapeCollisionResolutionQueryShape
--- @field private otherShape slick.collision.shapeCollisionResolutionQueryShape
local shapeCollisionResolutionQuery = {}
local metatable = { __index = shapeCollisionResolutionQuery }

--- @return slick.collision.shapeCollisionResolutionQueryShape
local function _newQueryShape()
    return {
        axesCount = 0,
        axes = {},
        interval = interval.new(),
    }
end

--- @return slick.collision.shapeCollisionResolutionQuery
function shapeCollisionResolutionQuery.new()
    return setmetatable({
        currentShape = _newQueryShape(),
        otherShape = _newQueryShape(),
        collision = false,
        depth = 0,
        normal = point.new(),
        firstTime = 0,
        lastTime = 0
    }, metatable)
end

--- @return slick.collision.shape
function shapeCollisionResolutionQuery:getSelfShape()
    return self.currentShape.shape
end

--- @return slick.collision.shape
function shapeCollisionResolutionQuery:getOtherShape()
    return self.otherShape.shape
end

--- @private
function shapeCollisionResolutionQuery:_swapShapes()
    self.otherShape, self.currentShape = self.currentShape, self.otherShape
end

--- @private
function shapeCollisionResolutionQuery:_beginQuery()
    self.currentShape.axesCount = 0
    self.otherShape.axesCount = 0

    self.collision = false
    self.depth = 0
    self.firstTime = -math.huge
    self.lastTime = math.huge
    self.normal:init(0, 0)
end

function shapeCollisionResolutionQuery:addAxis()
    self.currentShape.axesCount = self.currentShape.axesCount + 1
    local index = self.currentShape.axesCount
    local axis = self.currentShape.axes[index]
    if not axis then
        axis = point.new()
        self.currentShape.axes[index] = axis
    end

    return axis
end

local _cachedCircleNormal = point.new()
local _cachedCirclePointPosition = point.new()
local _cachedCirclePointVelocity = point.new()
local _cachedCirclePointSegment = segment.new()

--- @private
--- @param selfShape slick.collision.circle
--- @param otherShape slick.collision.circle
--- @param selfVelocity slick.geometry.point
--- @param otherVelocity slick.geometry.point
function shapeCollisionResolutionQuery:_performCircle(selfShape, otherShape, selfVelocity, otherVelocity)
    -- Check if they are currently colliding.
    selfShape.center:direction(otherShape.center, _cachedCircleNormal)
    local radius = selfShape.radius + otherShape.radius
    local magnitude = _cachedCircleNormal:lengthSquared()
    if magnitude < radius ^ 2 then
        self.collision = true
        self.firstTime = 0
        self.lastTime = 0
        self.depth = math.sqrt(magnitude)

        if self.depth > 0 then
            _cachedCircleNormal:divideScalar(self.depth, self.normal)
        end

        return
    end

    otherShape.center:sub(selfShape.center, _cachedCirclePointPosition)
    otherVelocity:sub(selfVelocity, _cachedCirclePointVelocity)

    _cachedCirclePointSegment.a:init(_cachedCirclePointPosition.x, _cachedCirclePointPosition.y)
    _cachedCirclePointPosition:add(_cachedCirclePointVelocity, _cachedCirclePointSegment.b)

    local p1 = _cachedCirclePointSegment.a
    local p2 = _cachedCirclePointSegment.b
    local r = selfShape.radius + otherShape.radius

    local a = (p2.x - p1.x) ^ 2 + (p2.y - p1.y) ^ 2
    local b = 2 * ((p2.x - p1.x) * p1.x + (p2.y - p1.y) * p1.y)
    local c = p1.x ^ 2 + p1.y ^ 2 - r ^ 2

    local s = b * b - 4 * a * c
    if a < 0 or s < 0 then
        return
    end

    local u = -b + math.sqrt(s) / (2 * a)
    local v = -b - math.sqrt(s) / (2 * a)

    if u >= 0 and u <= 1 and v >= 0 and v <= 1 then
        self.collision = true
        self.depth = 0
        self.firstTime = math.min(u, v)
        self.lastTime = math.max(u, v)
        otherVelocity:normalize(self.normal)
    end
end

local _cachedSelfVelocity = point.new()
local _cachedPendingAxis = point.new()
local _cachedDirection = point.new()

--- @param selfShape slick.collision.shape
--- @param otherShape slick.collision.shape
--- @param selfVelocity slick.geometry.point
--- @param otherVelocity slick.geometry.point
function shapeCollisionResolutionQuery:perform(selfShape, otherShape, selfVelocity, otherVelocity)
    self:_beginQuery()

    if util.is(selfShape, circle) and util.is(otherShape, circle) then
        --- @cast selfShape slick.collision.circle
        --- @cast otherShape slick.collision.circle
        self:_performCircle(selfShape, otherShape, selfVelocity, otherVelocity)
        return
    end

    self.currentShape.shape = selfShape
    self.otherShape.shape = otherShape
    
    self.currentShape.shape:getAxes(self)
    self:_swapShapes()
    self.currentShape.shape:getAxes(self)
    self:_swapShapes()
    
    selfVelocity:sub(otherVelocity, _cachedSelfVelocity)

    self.depth = math.huge
    local hit = false
    for i = 1, self.currentShape.axesCount + self.otherShape.axesCount do
        self.currentShape.interval:init()
        self.otherShape.interval:init()

        local axis
        if i <= self.currentShape.axesCount then
            axis = self.currentShape.axes[i]
        else
            axis = self.otherShape.axes[i - self.currentShape.axesCount]
        end

        hit = self:_handleAxis(axis, _cachedSelfVelocity)
        hit = hit or self.currentShape.interval:overlaps(self.otherShape.interval)
        if not hit then
            break
        end

        _cachedPendingAxis:init(axis.x, axis.y)
        local depth = self.currentShape.interval:distance(self.otherShape.interval)
        if self.currentShape.interval:contains(self.otherShape.interval) or self.otherShape.interval:contains(self.currentShape.interval) then
            local max = math.abs(self.currentShape.interval.max - self.otherShape.interval.max)
            local min = math.abs(self.currentShape.interval.min - self.otherShape.interval.min)

            if max > min then
                _cachedPendingAxis:init(-axis.x, -axis.y)
                depth = depth + min
            else
                depth = depth + max
            end
        end

        if depth < self.depth then
            self.depth = depth
            self.normal:init(axis.x, axis.y)
        end
    end

    self.collision = hit

    if hit then
        self.currentShape.shape.center:direction(self.otherShape.shape.center, _cachedDirection)
        _cachedDirection:normalize(_cachedDirection)

        if _cachedDirection:dot(self.normal) > 0 then
            self.normal:negate(self.normal)
        end
    else
        self.depth = 0
        self.firstTime = 0
        self.lastTime = 0
        self.normal:init(0, 0)
    end

    return self.collision
end

--- @param axis slick.geometry.point
--- @param velocity slick.geometry.point
function shapeCollisionResolutionQuery:_handleAxis(axis, velocity)
    local speed = velocity:dot(axis)

    self.currentShape.shape:project(self, axis, self.currentShape.interval)
    self:_swapShapes()
    self.currentShape.shape:project(self, axis, self.currentShape.interval)
    self:_swapShapes()

    local selfInterval = self.currentShape.interval
    local otherInterval = self.otherShape.interval

    if otherInterval.max < selfInterval.min then
        if speed <= 0 then
            return false
        end

        local u = (selfInterval.min - otherInterval.max) / speed
        self.firstTime = math.max(self.firstTime, u)

        local v = (selfInterval.max - otherInterval.min) / speed
        self.lastTime = math.min(self.lastTime, v)

        if self.firstTime > self.lastTime then
            return false
        end
    elseif selfInterval.min < otherInterval.max then
        if speed >= 0 then
            return false
        end

        local u = (selfInterval.max - otherInterval.min) / speed
        self.firstTime = math.max(self.firstTime, u)

        local v = (selfInterval.min - otherInterval.max) / speed
        self.lastTime = math.min(self.lastTime, v)
    else
        if speed > 0 then
            local t = (otherInterval.max - selfInterval.min) / speed
            self.lastTime = math.min(self.lastTime, t)

            if self.firstTime > self.lastTime then
                return false
            end
        elseif speed < 0 then
            local t = (selfInterval.min - otherInterval.max) / speed
            self.lastTime = math.min(self.lastTime, t)

            if self.firstTime > self.lastTime then
                return false
            end
        end
    end

    return true
end

--- @param shape slick.collision.shape
--- @param point slick.geometry.point
--- @return slick.geometry.point?
function shapeCollisionResolutionQuery:getClosestVertex(shape, point)
    local minDistance
    local result

    for i = 1, shape.vertexCount do
        local vertex = shape.vertices[i]
        local distance = vertex:distanceSquared(point)

        if distance < (minDistance or math.huge) then
            minDistance = distance
            result = vertex
        end
    end

    return result
end

function shapeCollisionResolutionQuery:getAxes()
    if util.is(self.otherShape, circle) then
        local c = self.otherShape

        --- @cast c slick.collision.circle
        local closest = self:getClosestVertex(self.currentShape.shape, c.center)

        if closest then
            local axis = self:addAxis()

            closest:direction(c.center, axis)
            axis:normalize(axis)
        end
    end

    for i = 1, self.currentShape.shape.normalCount do
        local normal = self.currentShape.shape.normals[i]

        local axis = self:addAxis()
        axis:init(normal.x, normal.y)
    end
end

function shapeCollisionResolutionQuery:project(axis, interval)
    for i = 1, self.currentShape.shape.vertexCount do
        local vertex = self.currentShape.shape.vertices[i]
        interval:update(vertex:dot(axis))
    end
end

return shapeCollisionResolutionQuery
