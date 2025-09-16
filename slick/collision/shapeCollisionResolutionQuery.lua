local interval = require "slick.collision.interval"
local point = require "slick.geometry.point"
local segment = require "slick.geometry.segment"
local slickmath = require "slick.util.slickmath"

local SIDE_NONE  = 0
local SIDE_LEFT  = -1
local SIDE_RIGHT = 1

--- @alias slick.collision.shapeCollisionResolutionQueryAxis {
---     parent: slick.collision.shapeCollisionResolutionQueryShape,
---     normal: slick.geometry.point,
---     segment: slick.geometry.segment,
--- }

--- @alias slick.collision.shapeCollisionResolutionQueryShape {
---     shape: slick.collision.shapeInterface,
---     offset: slick.geometry.point,
---     axesCount: number,
---     axes: slick.collision.shapeCollisionResolutionQueryAxis[],
---     currentInterval: slick.collision.interval,
---     minInterval: slick.collision.interval,
--- }

--- @class slick.collision.shapeCollisionResolutionQuery
--- @field epsilon number
--- @field collision boolean
--- @field normal slick.geometry.point
--- @field currentNormal slick.geometry.point
--- @field otherNormal slick.geometry.point
--- @field depth number
--- @field private otherDepth number
--- @field private currentDepth number
--- @field time number
--- @field currentOffset slick.geometry.point
--- @field otherOffset slick.geometry.point
--- @field contactPointsCount number
--- @field contactPoints slick.geometry.point[]
--- @field private firstTime number
--- @field private lastTime number
--- @field private currentShape slick.collision.shapeCollisionResolutionQueryShape
--- @field private otherShape slick.collision.shapeCollisionResolutionQueryShape
--- @field private axis slick.collision.shapeCollisionResolutionQueryAxis?
--- @field private otherAxis slick.collision.shapeCollisionResolutionQueryAxis?
--- @field private currentAxis slick.collision.shapeCollisionResolutionQueryAxis?
--- @field private relativeDirection slick.geometry.point
local shapeCollisionResolutionQuery = {}
local metatable = { __index = shapeCollisionResolutionQuery }

--- @return slick.collision.shapeCollisionResolutionQueryShape
local function _newQueryShape()
    return {
        offset = point.new(),
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
        currentDepth = 0,
        otherDepth = 0,
        normal = point.new(),
        currentNormal = point.new(),
        otherNormal = point.new(),
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
        relativeDirection = point.new()
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
    self.otherDepth = 0
    self.currentDepth = 0
    self.time = math.huge
    self.currentOffset:init(0, 0)
    self.otherOffset:init(0, 0)
    self.normal:init(0, 0)
    self.otherNormal:init(0, 0)
    self.currentNormal:init(0, 0)
    self.contactPointsCount = 0
end

--- @private
function shapeCollisionResolutionQuery:_beginQuery()
    self.currentShape.axesCount = 0
    self.otherShape.axesCount = 0
    self.axis = nil
    self.otherAxis = nil
    self.currentAxis = nil

    self.collision = false
    self.depth = 0
    self.otherDepth = 0
    self.currentDepth = 0
    self.firstTime = -math.huge
    self.lastTime = math.huge
    self.currentOffset:init(0, 0)
    self.otherOffset:init(0, 0)
    self.normal:init(0, 0)
    self.otherNormal:init(0, 0)
    self.currentNormal:init(0, 0)
    self.contactPointsCount = 0
    self.relativeDirection:init(0, 0)
end

function shapeCollisionResolutionQuery:addAxis()
    self.currentShape.axesCount = self.currentShape.axesCount + 1
    local index = self.currentShape.axesCount
    local axis = self.currentShape.axes[index]
    if not axis then
        axis = { parent = self.currentShape, normal = point.new(), segment = segment.new() }
        self.currentShape.axes[index] = axis
    end

    return axis
end

local _cachedOtherSegment = segment.new()
local _cachedCurrentPoint = point.new()
local _cachedOtherNormal = point.new()

--- @private
--- @param a slick.collision.shapeCollisionResolutionQueryShape
--- @param b slick.collision.shapeCollisionResolutionQueryShape
--- @param aOffset slick.geometry.point
--- @param bOffset slick.geometry.point
--- @param scalar number
--- @return boolean
function shapeCollisionResolutionQuery:_isShapeMovingAwayFromShape(a, b, aOffset, bOffset, scalar)
    local currentVertexCount = a.shape.vertexCount
    local currentVertices = a.shape.vertices

    local otherVertexCount = b.shape.vertexCount
    local otherVertices = b.shape.vertices

    for i = 1, otherVertexCount do
        local j = slickmath.wrap(i, 1, otherVertexCount)

        otherVertices[i]:add(bOffset, _cachedOtherSegment.a)
        otherVertices[j]:add(bOffset, _cachedOtherSegment.b)

        _cachedOtherSegment.a:direction(_cachedOtherSegment.b, _cachedOtherNormal)
        _cachedOtherNormal:normalize(_cachedOtherNormal)
        _cachedOtherNormal:left(_cachedOtherNormal)

        local sameSide = true
        for k = 1, currentVertexCount do
            currentVertices[k]:add(aOffset, _cachedCurrentPoint)

            local direction = slickmath.direction(_cachedOtherSegment.a, _cachedOtherSegment.b, _cachedCurrentPoint, self.epsilon)
            if direction < 0 then
                sameSide = false
                break
            end
        end
        
        if sameSide then
            if (scalar * self.relativeDirection:dot(_cachedOtherNormal)) >= 0 then
                return true
            end
        end
    end

    return false
end

local _cachedSelfVelocityDirection = point.new()
local _cachedOtherVelocityDirection = point.new()
local _cachedRelativeVelocity = point.new()
local _cachedSelfFutureCenter = point.new()
local _cachedSelfVelocityMinusOffset = point.new()
local _cachedDirection = point.new()

local _cachedSegmentA = segment.new()
local _cachedSegmentB = segment.new()

--- @private
--- @param selfShape slick.collision.commonShape
--- @param otherShape slick.collision.commonShape
--- @param selfOffset slick.geometry.point
--- @param otherOffset slick.geometry.point
--- @param selfVelocity slick.geometry.point
--- @param otherVelocity slick.geometry.point
function shapeCollisionResolutionQuery:_performPolygonPolygonProjection(selfShape, otherShape, selfOffset, otherOffset, selfVelocity, otherVelocity)
    self.currentShape.shape = selfShape
    self.currentShape.offset:init(selfOffset.x, selfOffset.y)
    self.otherShape.shape = otherShape
    self.otherShape.offset:init(otherOffset.x, otherOffset.y)
    
    self.currentShape.shape:getAxes(self)
    self:_swapShapes()
    self.currentShape.shape:getAxes(self)
    self:_swapShapes()
    
    otherVelocity:sub(selfVelocity, _cachedRelativeVelocity)
    selfVelocity:add(selfShape.center, _cachedSelfFutureCenter)

    selfVelocity:sub(selfOffset, _cachedSelfVelocityMinusOffset)

    _cachedRelativeVelocity:normalize(self.relativeDirection)
    self.relativeDirection:negate(self.relativeDirection)
    
    self.depth = math.huge
    self.otherDepth = math.huge
    self.currentDepth = math.huge
    
    local hit = true
    local side = SIDE_NONE
    
    local currentInterval = self.currentShape.currentInterval
    local otherInterval = self.otherShape.currentInterval

    if _cachedRelativeVelocity:lengthSquared() == 0 then
        for i = 1, self.currentShape.axesCount + self.otherShape.axesCount do
            local axis = self:_getAxis(i)

            currentInterval:init()
            otherInterval:init()

            self:_handleAxis(axis)

            if self:_compareIntervals(axis) then
                hit = true
            else
                hit = false
                break
            end
        end
    else
        local isTouching = true

        for i = 1, self.currentShape.axesCount + self.otherShape.axesCount do
            local axis = self:_getAxis(i)

            currentInterval:init()
            otherInterval:init()

            local willHit, futureSide = self:_handleTunnelAxis(axis, _cachedRelativeVelocity)
            if not willHit then
                hit = false

                if not isTouching then
                    break
                end
            end

            if isTouching and not self:_compareIntervals(axis) then
                isTouching = false

                if not hit then
                    break
                end
            end

            if futureSide then
                currentInterval:copy(self.currentShape.minInterval)
                otherInterval:copy(self.otherShape.minInterval)

                side = futureSide
            end
        end
    end

    if hit and self.depth < self.epsilon and _cachedRelativeVelocity:lengthSquared() > 0 then
        hit = not (
            self:_isShapeMovingAwayFromShape(self.currentShape, self.otherShape, selfOffset, otherOffset, 1) or
            self:_isShapeMovingAwayFromShape(self.otherShape, self.currentShape, otherOffset, selfOffset, -1))
    end

    if self.firstTime > 1 then
        hit = false
    end

    if not hit and self.depth < self.epsilon then
        self.depth = 0
    end

    if self.firstTime == -math.huge and self.lastTime >= 0 and self.lastTime <= 1 then
        self.firstTime = 0
    end

    local isSelfMovingTowardsOther = false
    if hit then
        self.currentShape.shape.center:direction(self.otherShape.shape.center, _cachedDirection)
        _cachedDirection:normalize(_cachedDirection)

        isSelfMovingTowardsOther = _cachedDirection:dot(self.normal) < 0
        if not isSelfMovingTowardsOther then
            self.normal:negate(self.normal)
        end
    end

    if hit and self.firstTime <= 0 and self.depth < math.huge then
        local selfSpeed = selfVelocity:length()
        local otherSpeed = otherVelocity:length()

        _cachedSelfVelocityDirection:init(selfVelocity.x, selfVelocity.y)
        if selfSpeed > 0 then
            _cachedSelfVelocityDirection:divideScalar(selfSpeed, _cachedSelfVelocityDirection)
        end

        _cachedOtherVelocityDirection:init(otherVelocity.x, otherVelocity.y)
        if otherSpeed > 0 then
            _cachedOtherVelocityDirection:divideScalar(otherSpeed, _cachedOtherVelocityDirection)
        end

        local areShapesMovingApart = selfSpeed == 0 or otherSpeed == 0 or
        _cachedSelfVelocityDirection:dot(_cachedOtherVelocityDirection) <= self.epsilon
        local isOtherShapeMovingAwayFromEdge = _cachedSelfVelocityDirection:dot(self.normal) > -self.epsilon
        local isSelfShapeMovingFasterishThanOtherShape = selfSpeed >= otherSpeed
        local isMoving = selfSpeed > 0 or otherSpeed > 0

        if areShapesMovingApart and isOtherShapeMovingAwayFromEdge and isSelfShapeMovingFasterishThanOtherShape and isMoving then
            hit = false
        end
    end

    if not hit then
        self:_clear()
        return
    end

    if hit and self.firstTime < 0 and self.depth <= self.epsilon and self.axis.parent == self.currentShape then
        self.currentNormal:init(self.normal.x, self.normal.y)
        self.normal:init(self.otherNormal.x, self.otherNormal.y)

        local otherDirection = slickmath.direction(self.otherAxis.segment.a, self.otherAxis.segment.b, self.currentShape.shape.center, self.epsilon)
        if otherDirection > 0 then
            self.normal:negate(self.normal)
        end
    end

    self.time = math.max(self.firstTime, 0)

    if (self.firstTime == 0 and self.lastTime <= 1) or (self.firstTime == -math.huge and self.lastTime == math.huge) then
        self.normal:multiplyScalar(self.depth, self.currentOffset)
        self.normal:multiplyScalar(-self.depth, self.otherOffset)
    else
        selfVelocity:multiplyScalar(self.time, self.currentOffset)
        otherVelocity:multiplyScalar(self.time, self.otherOffset)
    end

    if self.time > 0 and self.currentOffset:lengthSquared() == 0 then
        self.time = 0
        self.depth = 0
    end

    if side == SIDE_RIGHT or side == SIDE_LEFT then
        local currentInterval = self.currentShape.minInterval
        local otherInterval = self.otherShape.minInterval

        currentInterval:sort()
        otherInterval:sort()

        if side == SIDE_LEFT then
            local selfA = currentInterval.indices[currentInterval.minIndex].index
            local selfB = currentInterval.indices[currentInterval.minIndex + 1].index
            if ((selfA == 1 or selfB == 1) and (selfA == selfShape.vertexCount or selfB == selfShape.vertexCount)) then
                selfA, selfB = math.max(selfA, selfB), math.min(selfA, selfB)
            else
                selfA, selfB = math.min(selfA, selfB), math.max(selfA, selfB)
            end

            selfShape.vertices[selfA]:add(self.currentOffset, _cachedSegmentA.a)
            selfShape.vertices[selfB]:add(self.currentOffset, _cachedSegmentA.b)

            _cachedSegmentA.a:direction(_cachedSegmentA.b, self.currentNormal)
            self.currentNormal:normalize(self.currentNormal)
            self.currentNormal:left(self.currentNormal)

            local otherA = otherInterval.indices[otherInterval.maxIndex].index
            local otherB = otherInterval.indices[otherInterval.maxIndex - 1].index
            if ((otherA == 1 or otherB == 1) and (otherA == otherShape.vertexCount or otherB == otherShape.vertexCount)) then
                otherA, otherB = math.max(otherA, otherB), math.min(otherA, otherB)
            else
                otherA, otherB = math.min(otherA, otherB), math.max(otherA, otherB)
            end
            
            otherShape.vertices[otherA]:add(self.otherOffset, _cachedSegmentB.a)
            otherShape.vertices[otherB]:add(self.otherOffset, _cachedSegmentB.b)

            _cachedSegmentB.a:direction(_cachedSegmentB.b, self.normal)
            self.normal:normalize(self.normal)
            self.normal:left(self.normal)
        elseif side == SIDE_RIGHT then
            local selfA = currentInterval.indices[currentInterval.maxIndex].index
            local selfB = currentInterval.indices[currentInterval.maxIndex - 1].index
            if ((selfA == 1 or selfB == 1) and (selfA == selfShape.vertexCount or selfB == selfShape.vertexCount)) then
                selfA, selfB = math.max(selfA, selfB), math.min(selfA, selfB)
            else
                selfA, selfB = math.min(selfA, selfB), math.max(selfA, selfB)
            end

            selfShape.vertices[selfA]:add(self.currentOffset, _cachedSegmentA.a)
            selfShape.vertices[selfB]:add(self.currentOffset, _cachedSegmentA.b)

            _cachedSegmentA.a:direction(_cachedSegmentA.b, self.currentNormal)
            self.currentNormal:normalize(self.currentNormal)
            self.currentNormal:left(self.currentNormal)

            local otherA = otherInterval.indices[otherInterval.minIndex].index
            local otherB = otherInterval.indices[otherInterval.minIndex + 1].index
            if ((otherA == 1 or otherB == 1) and (otherA == otherShape.vertexCount or otherB == otherShape.vertexCount)) then
                otherA, otherB = math.max(otherA, otherB), math.min(otherA, otherB)
            else
                otherA, otherB = math.min(otherA, otherB), math.max(otherA, otherB)
            end

            otherShape.vertices[otherA]:add(self.otherOffset, _cachedSegmentB.a)
            otherShape.vertices[otherB]:add(self.otherOffset, _cachedSegmentB.b)

            _cachedSegmentB.a:direction(_cachedSegmentB.b, self.normal)
            self.normal:normalize(self.normal)
            self.normal:left(self.normal)
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

            if self.time > 0 then
                _cachedSegmentA.a:add(self.currentOffset, _cachedSegmentA.a)
                _cachedSegmentA.b:add(self.currentOffset, _cachedSegmentA.b)
            end

            for k = 1, otherShape.vertexCount do
                _cachedSegmentB:init(otherShape.vertices[k], otherShape.vertices[k % otherShape.vertexCount + 1])

                if self.time > 0 then
                    _cachedSegmentB.a:add(self.otherOffset, _cachedSegmentB.a)
                    _cachedSegmentB.b:add(self.otherOffset, _cachedSegmentB.b)
                end
                
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
    self.collision = true
end

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
    local nextCount = self.contactPointsCount + 1
    local contactPoint = self.contactPoints[nextCount]
    if not contactPoint then
        contactPoint = point.new()
        self.contactPoints[nextCount] = contactPoint
    end

    contactPoint:init(x, y)

    for i = 1, self.contactPointsCount do
        if contactPoint:distanceSquared(self.contactPoints[i]) < self.epsilon ^ 2 then
            return
        end
    end
    self.contactPointsCount = nextCount
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

    if axis.parent == self.otherShape and depth < self.otherDepth then
        self.otherDepth = depth
        self.otherNormal:init(axis.normal.x, axis.normal.y)

        if negate then
            self.otherNormal:negate(self.otherNormal)
        end

        self.otherAxis = axis
    end

    if axis.parent == self.currentShape and depth < self.currentDepth then
        self.currentDepth = depth
        self.currentNormal:init(axis.normal.x, axis.normal.y)

        if negate then
            self.currentNormal:negate(self.currentNormal)
        end

        self.currentAxis = axis
    end

    if depth < self.depth then
        self.depth = depth
        self.normal:init(axis.normal.x, axis.normal.y)
        self.axis = axis

        if negate then
            self.normal:negate(self.normal)
        end
    end

    return true
end

--- @param selfShape slick.collision.shapeInterface
--- @param otherShape slick.collision.shapeInterface
--- @param selfOffset slick.geometry.point
--- @param otherOffset slick.geometry.point
--- @param selfVelocity slick.geometry.point
--- @param otherVelocity slick.geometry.point
function shapeCollisionResolutionQuery:performProjection(selfShape, otherShape, selfOffset, otherOffset, selfVelocity, otherVelocity)
    self:_beginQuery()
    self:_performPolygonPolygonProjection(selfShape, otherShape, selfOffset, otherOffset, selfVelocity, otherVelocity)

    if self.collision then
        self.normal:round(self.normal, self.epsilon)
        self.normal:normalize(self.normal)
    end

    return self.collision
end

--- @private
function shapeCollisionResolutionQuery:_clear()
    self.depth = 0
    self.time = 0
    self.normal:init(0, 0)
    self.contactPointsCount = 0
end

function shapeCollisionResolutionQuery:_handleAxis(axis)
    self.currentShape.shape:project(self, axis.normal, self.currentShape.currentInterval, self.currentShape.offset)
    self:_swapShapes()
    self.currentShape.shape:project(self, axis.normal, self.currentShape.currentInterval, self.currentShape.offset)
    self:_swapShapes()
end

--- @param axis slick.collision.shapeCollisionResolutionQueryAxis
--- @param velocity slick.geometry.point
--- @return boolean, -1 | 0 | 1 | nil
function shapeCollisionResolutionQuery:_handleTunnelAxis(axis, velocity)
    local speed = velocity:dot(axis.normal)

    self.currentShape.shape:project(self, axis.normal, self.currentShape.currentInterval, self.currentShape.offset)
    self:_swapShapes()
    self.currentShape.shape:project(self, axis.normal, self.currentShape.currentInterval, self.currentShape.offset)
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

local _cachedGetAxesCircleCenter = point.new()
function shapeCollisionResolutionQuery:getAxes()
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
