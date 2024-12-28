local circle = require "slick.collision.circle"
local interval = require "slick.collision.interval"
local point = require "slick.geometry.point"
local segment = require "slick.geometry.segment"
local util = require "slick.util"
local slickmath = require "slick.util.slickmath"

local SIDE_NONE  = 0
local SIDE_LEFT  = -1
local SIDE_RIGHT = 1

--- @alias slick.collision.shapeCollisionResolutionQueryAxis {
---     normal: slick.geometry.point,
---     segment: slick.geometry.segment,
--- }

--- @alias slick.collision.shapeCollisionResolutionQueryShape {
---     shape: slick.collision.shapeInterface,
---     axesCount: number,
---     axes: slick.collision.shapeCollisionResolutionQueryAxis[],
---     currentInterval: slick.collision.interval,
---     minInterval: slick.collision.interval,
--- }

--- @class slick.collision.shapeCollisionResolutionQuery
--- @field epsilon number
--- @field collision boolean
--- @field normal slick.geometry.point
--- @field depth number
--- @field time number
--- @field currentOffset slick.geometry.point
--- @field otherOffset slick.geometry.point
--- @field contactPointsCount number
--- @field contactPoints slick.geometry.point[]
--- @field segment slick.geometry.segment
--- @field private firstTime number
--- @field private lastTime number
--- @field private currentShape slick.collision.shapeCollisionResolutionQueryShape
--- @field private otherShape slick.collision.shapeCollisionResolutionQueryShape
local shapeCollisionResolutionQuery = {}
local metatable = { __index = shapeCollisionResolutionQuery }

--- @return slick.collision.shapeCollisionResolutionQueryShape
local function _newQueryShape()
    return {
        axesCount = 0,
        axes = {},
        currentInterval = interval.new(),
        minInterval = interval.new(),
    }
end

--- @param E number?
--- @return slick.collision.shapeCollisionResolutionQuery
function shapeCollisionResolutionQuery.new(E)
    return setmetatable({
        epsilon = E or slickmath.EPSILON,
        collision = false,
        depth = 0,
        normal = point.new(),
        time = 0,
        firstTime = 0,
        lastTime = 0,
        currentOffset = point.new(),
        otherOffset = point.new(),
        contactPointsCount = 0,
        contactPoints = { point.new() },
        segment = segment.new(),
        currentShape = _newQueryShape(),
        otherShape = _newQueryShape(),
    }, metatable)
end

--- @return slick.collision.shapeInterface
function shapeCollisionResolutionQuery:getSelfShape()
    return self.currentShape.shape
end

--- @return slick.collision.shapeInterface
function shapeCollisionResolutionQuery:getOtherShape()
    return self.otherShape.shape
end

--- @private
function shapeCollisionResolutionQuery:_swapShapes()
    self.otherShape, self.currentShape = self.currentShape, self.otherShape
end

function shapeCollisionResolutionQuery:reset()
    self.collision = false
    self.depth = 0
    self.time = math.huge
    self.currentOffset:init(0, 0)
    self.otherOffset:init(0, 0)
    self.normal:init(0, 0)
    self.contactPointsCount = 0
    self.segment.a:init(0, 0)
    self.segment.b:init(0, 0)
end

--- @private
function shapeCollisionResolutionQuery:_beginQuery()
    self.currentShape.axesCount = 0
    self.otherShape.axesCount = 0

    self.collision = false
    self.depth = 0
    self.firstTime = -math.huge
    self.lastTime = math.huge
    self.currentOffset:init(0, 0)
    self.otherOffset:init(0, 0)
    self.normal:init(0, 0)
    self.contactPointsCount = 0
end

function shapeCollisionResolutionQuery:addAxis()
    self.currentShape.axesCount = self.currentShape.axesCount + 1
    local index = self.currentShape.axesCount
    local axis = self.currentShape.axes[index]
    if not axis then
        axis = { normal = point.new(), segment = segment.new() }
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

local _cachedRelativeVelocity = point.new()
local _cachedSelfFutureCenter = point.new()
local _cachedDirection = point.new()
local _cachedCurentOffset = point.new()

local _cachedSegmentA = segment.new()
local _cachedSegmentB = segment.new()

--- @private
--- @param index number
--- @return slick.collision.shapeCollisionResolutionQueryAxis
function shapeCollisionResolutionQuery:_getAxis(index)
    local axis
    if index <= self.currentShape.axesCount then
        axis = self.currentShape.axes[index]
    else
        axis = self.otherShape.axes[index - self.currentShape.axesCount]
    end

    return axis
end

--- @private
--- @param x number
--- @param y number
function shapeCollisionResolutionQuery:_addContactPoint(x, y)
    self.contactPointsCount = self.contactPointsCount + 1
    local contactPoint = self.contactPoints[self.contactPointsCount]
    if not contactPoint then
        contactPoint = point.new()
        self.contactPoints[self.contactPointsCount] = contactPoint
    end

    contactPoint:init(x, y)
end

--- @private
--- @param axis slick.collision.shapeCollisionResolutionQueryAxis
--- @return boolean
function shapeCollisionResolutionQuery:_compareIntervals(axis)
    local currentInterval = self.currentShape.currentInterval
    local otherInterval = self.otherShape.currentInterval

    if not currentInterval:overlaps(otherInterval) then
        return false
    end

    local depth = currentInterval:distance(otherInterval)
    local negate = false
    if currentInterval:contains(otherInterval) or otherInterval:contains(currentInterval) then
        local max = math.abs(currentInterval.max - otherInterval.max)
        local min = math.abs(currentInterval.min - otherInterval.min)

        if max > min then
            negate = true
            depth = depth + min
        else
            depth = depth + max
        end
    end

    if depth < self.depth then
        self.depth = depth
        self.normal:init(axis.normal.x, axis.normal.y)
        self.segment:init(axis.segment.a, axis.segment.b)

        if negate then
            self.normal:negate(self.normal)
        end
    end

    return true
end

--- @param selfShape slick.collision.shapeInterface
--- @param otherShape slick.collision.shapeInterface
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
    
    otherVelocity:sub(selfVelocity, _cachedRelativeVelocity)
    selfVelocity:add(selfShape.center, _cachedSelfFutureCenter)
    
    self.depth = math.huge
    
    local hit = false
    local side = SIDE_NONE
    
    local currentInterval = self.currentShape.currentInterval
    local otherInterval = self.otherShape.currentInterval

    for i = 1, self.currentShape.axesCount + self.otherShape.axesCount do
        local axis = self:_getAxis(i)

        currentInterval:init()
        otherInterval:init()

        local willHit, futureSide = self:_handleTunnelAxis(axis, _cachedRelativeVelocity)
        if willHit then
            hit = true
        else
            hit = false
            break
        end

        if futureSide then
            currentInterval:copy(self.currentShape.minInterval)
            otherInterval:copy(self.otherShape.minInterval)

            side = futureSide
        end
    end

    if hit and side == SIDE_NONE then
        selfVelocity:multiplyScalar(math.max(self.firstTime, 0), _cachedCurentOffset)

        self.depth = math.huge

        hit = false
        for i = 1, self.currentShape.axesCount + self.otherShape.axesCount do
            local axis = self:_getAxis(i)
            
            currentInterval:init()
            otherInterval:init()
            
            self:_handleAxis(axis, _cachedCurentOffset)
            hit = self:_compareIntervals(axis)
            if not hit then
                hit = false
                break
            end
        end
    end

    if self.firstTime > 1 then
        hit = false
    end

    if self.depth < self.epsilon then
        self.depth = 0
    end

    if self.firstTime == -math.huge and self.lastTime >= 0 and self.lastTime <= 1 then
        self.firstTime = 0
    end

    self.collision = hit

    if hit then
        self.currentShape.shape.center:direction(self.otherShape.shape.center, _cachedDirection)
        _cachedDirection:normalize(_cachedDirection)

        if _cachedDirection:dot(self.normal) > 0 then
            self.normal:negate(self.normal)
        end

        self.time = math.max(self.firstTime, 0)

        if self.time == 0 and self.depth > 0 and self.depth < math.huge then
            self.normal:multiplyScalar(self.depth, self.currentOffset)
            selfVelocity:add(self.currentOffset, self.currentOffset)

            self.normal:multiplyScalar(-self.depth, self.otherOffset)
            otherVelocity:add(self.otherOffset, self.otherOffset)
        else
            selfVelocity:multiplyScalar(self.time, self.currentOffset)
            otherVelocity:multiplyScalar(self.time, self.otherOffset)
        end

        if side == SIDE_RIGHT or side == SIDE_LEFT then
            local currentInterval = self.currentShape.minInterval
            local otherInterval = self.otherShape.minInterval

            currentInterval:sort()
            otherInterval:sort()

            if side == SIDE_LEFT then
                selfShape.vertices[currentInterval.indices[currentInterval.minIndex].index]:add(self.currentOffset, _cachedSegmentA.a)
                selfShape.vertices[currentInterval.indices[currentInterval.minIndex + 1].index]:add(self.currentOffset, _cachedSegmentA.b)

                otherShape.vertices[otherInterval.indices[otherInterval.maxIndex - 1].index]:add(self.otherOffset, _cachedSegmentB.a)
                otherShape.vertices[otherInterval.indices[otherInterval.maxIndex].index]:add(self.otherOffset, _cachedSegmentB.b)

                _cachedSegmentB.a:direction(_cachedSegmentB.b, self.normal)
            elseif side == SIDE_RIGHT then
                otherShape.vertices[otherInterval.indices[otherInterval.minIndex].index]:add(self.otherOffset, _cachedSegmentA.a)
                otherShape.vertices[otherInterval.indices[otherInterval.minIndex + 1].index]:add(self.otherOffset, _cachedSegmentA.b)
                
                selfShape.vertices[currentInterval.indices[currentInterval.maxIndex - 1].index]:add(self.currentOffset, _cachedSegmentB.a)
                selfShape.vertices[currentInterval.indices[currentInterval.maxIndex].index]:add(self.currentOffset, _cachedSegmentB.b)
                
                _cachedSegmentA.a:direction(_cachedSegmentA.b, self.normal)
            end

            self.normal:normalize(self.normal)
            self.normal:left(self.normal)
            if _cachedDirection:dot(self.normal) > 0 then
                self.normal:negate(self.normal)
            end

            local intersection, x, y
            if _cachedSegmentA:overlap(_cachedSegmentB) then
                intersection, x, y = slickmath.intersection(_cachedSegmentA.a, _cachedSegmentA.b, _cachedSegmentB.a, _cachedSegmentB.b, self.epsilon)
                if not intersection or not (x and y) then
                    intersection, x, y = _cachedSegmentA:intersection(_cachedSegmentB, self.epsilon)
                    if intersection and x and y then
                        self:_addContactPoint(x, y)
                    end

                    intersection, x, y = _cachedSegmentB:intersection(_cachedSegmentA, self.epsilon)
                    if intersection and x and y then
                        self:_addContactPoint(x, y)
                    end
                else
                    if intersection and x and y then
                        self:_addContactPoint(x, y)
                    end
                end
            end
        elseif side == SIDE_NONE then
            for j = 1, selfShape.vertexCount do
                _cachedSegmentA:init(selfShape.vertices[j], selfShape.vertices[j % selfShape.vertexCount + 1])
                _cachedSegmentA.a:add(self.currentOffset, _cachedSegmentA.a)
                _cachedSegmentA.b:add(self.currentOffset, _cachedSegmentA.b)
                for k = 1, otherShape.vertexCount do
                    _cachedSegmentB:init(otherShape.vertices[k], otherShape.vertices[k % otherShape.vertexCount + 1])
                    _cachedSegmentB.a:add(self.otherOffset, _cachedSegmentB.a)
                    _cachedSegmentB.b:add(self.otherOffset, _cachedSegmentB.b)
                    
                    if _cachedSegmentA:overlap(_cachedSegmentB) then
                        local intersection, x, y = slickmath.intersection(_cachedSegmentA.a, _cachedSegmentA.b, _cachedSegmentB.a, _cachedSegmentB.b, self.epsilon)
                        if intersection and x and y then
                            self:_addContactPoint(x, y)
                        end
                    end
                end
            end
        end

        self.time = math.max(self.firstTime, 0)
    else
        self.depth = 0
        self.time = 0
        self.normal:init(0, 0)
        self.contactPointsCount = 0
        self.segment.a:init(0, 0)
        self.segment.b:init(0, 0)
    end

    return self.collision
end

local _cachedCircleCenterProjectedS = point.new()
local _cachedCircleCenterProjectionDirection = point.new()

--- @private
--- @param s slick.geometry.segment
--- @param shape slick.collision.shapeInterface
--- @param result slick.geometry.point
function shapeCollisionResolutionQuery:_getClosestVertexToEdge(s, shape, result)
    if util.is(shape, circle) then
        --- @cast shape slick.collision.circle
        s:project(shape.center, _cachedCircleCenterProjectedS)

        shape.center:direction(_cachedCircleCenterProjectedS, _cachedCircleCenterProjectionDirection)
        _cachedCircleCenterProjectionDirection:normalize(_cachedCircleCenterProjectionDirection)

        _cachedCircleCenterProjectionDirection:multiplyScalar(shape.radius, result)
        shape.center:add(result, result)

        return
    end

    local closestVertex
    local minDistance = math.huge
    for i = 1, shape.vertexCount do
        local vertex = shape.vertices[i]
        local distance = s:distanceSquared(vertex)
        if distance < minDistance then
            closestVertex = vertex
            minDistance = distance
        end
    end

    result:init(closestVertex.x, closestVertex.y)
end

function shapeCollisionResolutionQuery:_handleAxis(axis, offset)
    self.currentShape.shape:project(self, axis.normal, self.currentShape.currentInterval, offset)
    self:_swapShapes()
    self.currentShape.shape:project(self, axis.normal, self.currentShape.currentInterval)
    self:_swapShapes()
end

--- @param axis slick.collision.shapeCollisionResolutionQueryAxis
--- @param velocity slick.geometry.point
--- @return boolean, -1 | 0 | 1 | nil
function shapeCollisionResolutionQuery:_handleTunnelAxis(axis, velocity)
    local speed = velocity:dot(axis.normal)

    self.currentShape.shape:project(self, axis.normal, self.currentShape.currentInterval)
    self:_swapShapes()
    self.currentShape.shape:project(self, axis.normal, self.currentShape.currentInterval)
    self:_swapShapes()

    local selfInterval = self.currentShape.currentInterval
    local otherInterval = self.otherShape.currentInterval

    local side
    if otherInterval.max < selfInterval.min then
        if speed <= 0 then
            return false, nil
        end
        
        local u = (selfInterval.min - otherInterval.max) / speed
        if u > self.firstTime then
            side = SIDE_LEFT
            self.firstTime = u
        end
        
        local v = (selfInterval.max - otherInterval.min) / speed
        self.lastTime = math.min(self.lastTime, v)
        
        if self.firstTime > self.lastTime then
            return false, nil
        end
    elseif selfInterval.max < otherInterval.min then
        if speed >= 0 then
            return false, nil
        end

        local u = (selfInterval.max - otherInterval.min) / speed
        if u > self.firstTime then
            side = SIDE_RIGHT
            self.firstTime = u
        end

        local v = (selfInterval.min - otherInterval.max) / speed
        self.lastTime = math.min(self.lastTime, v)
    else
        if speed > 0 then
            local t = (selfInterval.max - otherInterval.min) / speed
            self.lastTime = math.min(self.lastTime, t)

            if self.firstTime > self.lastTime then
                return false, nil
            end
        elseif speed < 0 then
            local t = (selfInterval.min - otherInterval.max) / speed
            self.lastTime = math.min(self.lastTime, t)

            if self.firstTime > self.lastTime then
                return false, nil
            end
        end
    end

    if self.firstTime > self.lastTime then
        return false, nil
    end

    return true, side
end

--- @param shape slick.collision.shapeInterface
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
            axis.normal:normalize(axis)
            axis.segment:init(c.center, closest)
        end
    end

    --- @type slick.collision.shapeInterface
    local shape = self.currentShape.shape
    for i = 1, shape.normalCount do
        local normal = shape.normals[i]

        local axis = self:addAxis()
        axis.normal:init(normal.x, normal.y)
        axis.segment:init(shape.vertices[(i - 1) % shape.vertexCount + 1], shape.vertices[i % shape.vertexCount + 1])
    end
end

local _cachedOffsetVertex = point.new()

--- @param axis slick.geometry.point
--- @param interval slick.collision.interval
--- @param offset slick.geometry.point?
function shapeCollisionResolutionQuery:project(axis, interval, offset)
    for i = 1, self.currentShape.shape.vertexCount do
        local vertex = self.currentShape.shape.vertices[i]
        _cachedOffsetVertex:init(vertex.x, vertex.y)
        if offset then
            _cachedOffsetVertex:add(offset, _cachedOffsetVertex)
        end

        interval:update(_cachedOffsetVertex:dot(axis), i)
    end
end

return shapeCollisionResolutionQuery
