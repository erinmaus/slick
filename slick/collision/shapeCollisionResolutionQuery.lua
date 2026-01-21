local interval = require "slick.collision.interval"
local point = require "slick.geometry.point"
local segment = require "slick.geometry.segment"
local slickmath = require "slick.util.slickmath"
local slicktable = require "slick.util.slicktable"

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
--- @field currentDepth number
--- @field time number
--- @field currentOffset slick.geometry.point
--- @field otherOffset slick.geometry.point
--- @field contactPointsCount number
--- @field contactPoints slick.geometry.point[]
--- @field normals slick.geometry.point[]
--- @field alternateNormals slick.geometry.point[]
--- @field private allNormals slick.geometry.point[]
--- @field private allNormalsCount number
--- @field private depths number[]
--- @field private normalsShape slick.collision.shapeCollisionResolutionQueryShape[]
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
        normals = {},
        alternateNormals = {},
        depths = {},
        normalsShape = {},
        allNormals = {},
        allNormalsCount = 0,
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
    self.allNormalsCount = 0

    slicktable.clear(self.normals)
    slicktable.clear(self.alternateNormals)
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
    self.allNormalsCount = 0
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
            if (scalar * self.relativeDirection:dot(_cachedOtherNormal)) >= -self.epsilon then
                return true
            end
        end
    end

    return false
end

local _lineSegmentDirection = point.new()
local _lineSegmentRelativePosition = point.new()
local _lineSegmentShapePosition = point.new()
local _lineSegmentShapeVertexPosition = point.new()

--- @private
--- @param shape slick.collision.shapeInterface
--- @param offset slick.geometry.point
--- @param direction slick.geometry.point
--- @param point slick.geometry.point
--- @param fun fun(number, number): number
--- @return number
function shapeCollisionResolutionQuery:_dotShapeSegment(shape, offset, direction, point, fun)
    offset:sub(point, _lineSegmentRelativePosition)

    local dot
    for i = 1, shape.vertexCount do
        local vertex = shape.vertices[i]
        vertex:add(_lineSegmentRelativePosition, _lineSegmentShapeVertexPosition)
        local d = direction:dot(_lineSegmentShapeVertexPosition)
        dot = fun(d, dot or d)
    end

    return dot
end

--- @private
--- @param lineSegmentShape slick.collision.shapeCollisionResolutionQueryShape
--- @param otherShape slick.collision.shapeCollisionResolutionQueryShape
--- @param otherOffset slick.geometry.point
--- @param worldOffset slick.geometry.point
function shapeCollisionResolutionQuery:_correctLineSegmentNormals(lineSegmentShape, otherShape, otherOffset, worldOffset)
    assert(lineSegmentShape.shape.vertexCount == 2, "shape must be line segment")

    worldOffset:add(otherOffset, _lineSegmentShapePosition)
    
    local a = lineSegmentShape.shape.vertices[1]
    local b = lineSegmentShape.shape.vertices[2]
    a:direction(b, _lineSegmentDirection)

    -- Check if we're behind a (the beginning of the segment) or in front of b (the end of the segment)
    local dotA = self:_dotShapeSegment(otherShape.shape, _lineSegmentShapePosition, _lineSegmentDirection, a, math.max)
    local dotB = self:_dotShapeSegment(otherShape.shape, _lineSegmentShapePosition, _lineSegmentDirection, b, math.min)

    local normal, depth
    if lineSegmentShape == self.currentShape then
        normal = self.currentNormal
        depth = self.currentDepth
    elseif lineSegmentShape == self.otherShape then
        normal = self.otherNormal
        depth = self.otherDepth
    end
    assert(normal and depth, "incorrect shape; couldn't determine normal")

    if not (dotA > 0 and dotB < 0) then
        -- If we're not to the side of the segment, we need to swap the normal.
        self:_addNormal(depth, lineSegmentShape, normal.x, normal.y)
        normal:left(normal)

        if dotA >= 0 and dotB >= 0 then
            normal:negate(normal)
        end
    else
        otherShape.shape.center:add(_lineSegmentShapePosition, _lineSegmentShapePosition)
        local side = slickmath.direction(
            lineSegmentShape.shape.vertices[1],
            lineSegmentShape.shape.vertices[2],
            _lineSegmentShapePosition)

        if side == 0 then
            self:_addNormal(depth, lineSegmentShape, -normal.x, -normal.y)
        else
            normal:multiplyScalar(side, normal)
        end
    end

    normal:negate(normal)
    if normal == self.otherNormal then
        self.normal:init(normal.x, normal.y)
    end
end

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

    if hit and (self.depth == math.huge or self.depth < self.epsilon) and _cachedRelativeVelocity:lengthSquared() > 0 then
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

    if self.firstTime <= 0 and self.depth == 0 and _cachedRelativeVelocity:lengthSquared() == 0 then
        hit = false
    end

    if not hit then
        self:_clear()
        return
    end

    if hit and self.firstTime < 0 and self.axis.parent == self.currentShape then
        self.currentDepth = self.depth
        self.currentNormal:init(self.normal.x, self.normal.y)

        self.depth = self.otherDepth
        self.normal:init(self.otherNormal.x, self.otherNormal.y)

        local otherDirection = slickmath.direction(self.otherAxis.segment.a, self.otherAxis.segment.b, self.currentShape.shape.center, self.epsilon)
        if otherDirection > 0 then
            self.normal:negate(self.normal)
            self.currentNormal:negate(self.currentNormal)
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
            
            _cachedSegmentB.a:direction(_cachedSegmentB.b, self.otherNormal)
            self.otherNormal:normalize(self.otherNormal)
            self.otherNormal:left(self.otherNormal)
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

            _cachedSegmentB.a:direction(_cachedSegmentB.b, self.otherNormal)
            self.otherNormal:normalize(self.otherNormal)
            self.otherNormal:left(self.otherNormal)
        end

        self.normal:init(self.otherNormal.x, self.otherNormal.y)

        local intersection, x, y
        if _cachedSegmentA:overlap(_cachedSegmentB) then
            intersection, x, y = slickmath.intersection(_cachedSegmentA.a, _cachedSegmentA.b, _cachedSegmentB.a, _cachedSegmentB.b, self.epsilon)

            if intersection and not (x and y) then
                intersection = slickmath.intersection(_cachedSegmentA.a, _cachedSegmentA.a, _cachedSegmentB.a, _cachedSegmentB.b, self.epsilon)
                if intersection then
                    self:_addContactPoint(_cachedSegmentA.a.x, _cachedSegmentB.a.y)
                end

                intersection = slickmath.intersection(_cachedSegmentA.b, _cachedSegmentA.b, _cachedSegmentB.a, _cachedSegmentB.b, self.epsilon)
                if intersection then
                    self:_addContactPoint(_cachedSegmentA.b.x, _cachedSegmentB.b.y)
                end

                intersection = slickmath.intersection(_cachedSegmentB.a, _cachedSegmentB.a, _cachedSegmentA.a, _cachedSegmentA.b, self.epsilon)
                if intersection then
                    self:_addContactPoint(_cachedSegmentB.a.x, _cachedSegmentB.a.y)
                end

                intersection = slickmath.intersection(_cachedSegmentB.b, _cachedSegmentB.b, _cachedSegmentA.a, _cachedSegmentA.b, self.epsilon)
                if intersection then
                    self:_addContactPoint(_cachedSegmentB.b.x, _cachedSegmentB.b.y)
                end
            elseif intersection and x and y then
                self:_addContactPoint(x, y)
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

    if self.depth == math.huge then
        self.depth = 0
    end

    if self.currentDepth == math.huge then
        self.currentDepth = 0
    end

    if self.currentShape.shape.vertexCount == 2 then
        self:_correctLineSegmentNormals(self.currentShape, self.otherShape, self.otherOffset, otherOffset)
    end
    
    if self.otherShape.shape.vertexCount == 2 then
        self:_correctLineSegmentNormals(self.otherShape, self.currentShape, self.currentOffset, selfOffset)
    end
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
--- @param depth number
--- @param shape slick.collision.shapeCollisionResolutionQueryShape
--- @param x number
--- @param y number
function shapeCollisionResolutionQuery:_addNormal(depth, shape, x, y)
    local nextCount = self.allNormalsCount + 1
    local normal = self.allNormals[nextCount]
    if not normal then
        normal = point.new()
        self.allNormals[nextCount] = normal
    end

    normal:init(x, y)
    normal:round(normal, self.epsilon)
    normal:normalize(normal)

    self.depths[nextCount] = depth
    self.normalsShape[nextCount] = shape
    self.allNormalsCount = nextCount
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

local _intervalAxisNormal = point.new()

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

    _intervalAxisNormal:init(axis.normal.x, axis.normal.y)
    if negate then
        _intervalAxisNormal:negate(_intervalAxisNormal)
    end

    if axis.parent == self.otherShape and slickmath.less(depth, self.otherDepth, self.epsilon) then
        if depth < self.otherDepth then
            self.otherDepth = depth
            self.otherNormal:init(_intervalAxisNormal.x, _intervalAxisNormal.y)
            self.otherAxis = axis
        end

        self:_addNormal(depth, self.otherShape, _intervalAxisNormal.x, _intervalAxisNormal.y)
    end

    if axis.parent == self.currentShape and slickmath.less(depth, self.currentDepth, self.epsilon) then
        if depth < self.currentDepth then
            self.currentDepth = depth
            self.currentNormal:init(_intervalAxisNormal.x, _intervalAxisNormal.y)
            self.currentAxis = axis
        end

        self:_addNormal(depth, self.currentShape, _intervalAxisNormal.x, _intervalAxisNormal.y)
    end

    if depth < self.depth then
        self.depth = depth
        self.normal:init(_intervalAxisNormal.x, _intervalAxisNormal.y)
        self.axis = axis
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
        self.currentNormal:round(self.currentNormal, self.epsilon)
        self.currentNormal:normalize(self.currentNormal)

        slicktable.clear(self.normals)
        slicktable.clear(self.alternateNormals)

        table.insert(self.normals, self.normal)
        table.insert(self.alternateNormals, self.currentNormal)

        for i = 1, self.allNormalsCount do
            --- @type slick.geometry.point[]?
            local normals, depth
            if self.normalsShape[i] == self.otherShape then
                normals = self.normals
                depth = self.otherDepth
            elseif self.normalsShape[i] == self.currentShape then
                normals = self.alternateNormals
                depth = self.currentDepth
            end

            if normals and slickmath.equal(depth, self.depths[i], self.epsilon) then
                local normal = self.allNormals[i]

                local hasNormal = false
                for _, otherNormal in ipairs(normals) do
                    if otherNormal.x == normal.x and otherNormal.y == normal.y then
                        hasNormal = true
                        break
                    end
                end

                if not hasNormal then
                    table.insert(normals, normal)
                end
            end
        end
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
