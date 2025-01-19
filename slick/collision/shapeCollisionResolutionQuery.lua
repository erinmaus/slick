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
        axis = { parent = self.currentShape, normal = point.new(), segment = segment.new() }
        self.currentShape.axes[index] = axis
    end

    return axis
end

local _cachedCircleVelocity = point.new()
local _cachedPolygonOffset = point.new()
local _cachedCircleCenter = point.new()
local _cachedCircleProjectedSegment = segment.new()
local _cachedCircleOffsetCenter = point.new()
local _cachedCirclePolygonRelativeVelocity = point.new()
local _cachedCircleClosestPoint = point.new()
local _cachedCirclePolygonSegment = segment.new()
local _cachedCirclePolygonSegmentNormal = point.new()
local _cachedCirclePolygonIntersection = point.new()
local _cachedCirclePolygonRelativeVelocityDirection = point.new()
local _cachedCirclePolygonProjectedLine = point.new()
local _cachedCirclePolygonProjectedSegment = point.new()
local _cachedCirclePolygonProjectedLineOffset = point.new()
local _cachedCirclePolygonProjectedPoint = point.new()
local _cachedCirclePolygonNormal = point.new()

--- @private
--- @param i number
--- @param j number
--- @param polygonShape slick.collision.shape
--- @param circleCenter slick.geometry.point
--- @param radius number
--- @param polygonOffset slick.geometry.point
--- @return number
function shapeCollisionResolutionQuery:_tryAddCirclePolygonContactPoint(i, j, polygonShape, circleCenter, radius, polygonOffset)
    _cachedCirclePolygonSegment:init(polygonShape.vertices[i], polygonShape.vertices[j])
    polygonOffset:add(_cachedCirclePolygonSegment.a, _cachedCirclePolygonSegment.a)
    polygonOffset:add(_cachedCirclePolygonSegment.b, _cachedCirclePolygonSegment.b)

    local intersection, u, v = slickmath.lineCircleIntersection(_cachedCirclePolygonSegment, circleCenter, radius, self.epsilon)
    if intersection and u and v and ((slickmath.withinRange(u, 0, 1, self.epsilon)) or (slickmath.withinRange(v, 0, 1, self.epsilon))) then
        if slickmath.withinRange(u, 0, 1, self.epsilon) then
            _cachedCirclePolygonSegment:lerp(u, _cachedCirclePolygonIntersection)
            self:_addContactPoint(_cachedCirclePolygonIntersection.x, _cachedCirclePolygonIntersection.y)
        end
        
        if slickmath.withinRange(v, 0, 1, self.epsilon) and u ~= v then
            _cachedCirclePolygonSegment:lerp(v, _cachedCirclePolygonIntersection)
            self:_addContactPoint(_cachedCirclePolygonIntersection.x, _cachedCirclePolygonIntersection.y)
        end
    end

    return _cachedCirclePolygonSegment:distanceSquared(circleCenter)
end

--- @private
--- @param circleShape slick.collision.circle
--- @param polygonShape slick.collision.shape
--- @param circleOffset slick.geometry.point
--- @param polygonOffset slick.geometry.point
--- @param circleVelocity slick.geometry.point
--- @param polygonVelocity slick.geometry.point
--- @param circleBumpOffset slick.geometry.point
function shapeCollisionResolutionQuery:_performCirclePolygonProjection(circleShape, polygonShape, circleOffset, polygonOffset, circleVelocity, polygonVelocity, circleBumpOffset, polygonBumpOffset, selfShape)
    circleVelocity:sub(polygonVelocity, _cachedCirclePolygonRelativeVelocity)
    circleShape.center:add(circleOffset, _cachedCircleCenter)

    _cachedCircleProjectedSegment.a:init(_cachedCircleCenter.x, _cachedCircleCenter.y)
    _cachedCirclePolygonRelativeVelocity:add(_cachedCircleCenter, _cachedCircleProjectedSegment.b)

    local circleRadiusSquared = circleShape.radius ^ 2

    local minT = math.huge
    local minTIndex

    local maxT = -math.huge

    local minS = math.huge
    local minSIndex

    local circleInsidePolygon = true
    local polygonInsideCircle = false

    local minD = math.huge
    local maxD = -math.huge
    local minDIndex

    for i = 1, polygonShape.vertexCount do
        local j = slickmath.wrap(i, 1, polygonShape.vertexCount)

        local a = polygonShape.vertices[i]
        local b = polygonShape.vertices[j]
        local n = polygonShape.normals[i]

        a:add(polygonOffset, _cachedCirclePolygonSegment.a)
        b:add(polygonOffset, _cachedCirclePolygonSegment.b)

        if slickmath.direction(a, b, _cachedCircleCenter) > 0 then
            circleInsidePolygon = false
        end

        local d = _cachedCirclePolygonSegment:distanceSquared(_cachedCircleCenter)
        if d < minD then
            minD = d
            minDIndex = i
        end

        if d > maxD then
            maxD = d
        end

        local distanceASquared = _cachedCirclePolygonSegment.a:distanceSquared(_cachedCircleCenter)
        local distanceBSquared = _cachedCirclePolygonSegment.b:distanceSquared(_cachedCircleCenter)

        if distanceASquared <= circleRadiusSquared or distanceBSquared <= circleRadiusSquared then
            polygonInsideCircle = true--math.sqrt(distanceASquared) - circleShape.radius > self.epsilon
        end
    
        local intersection, u, v = slickmath.lineCircleIntersection(_cachedCirclePolygonSegment, _cachedCircleCenter, circleShape.radius, self.epsilon)
        if intersection and u and v and (slickmath.withinRange(u, 0, 1, self.epsilon) or slickmath.withinRange(v, 0, 1, self.epsilon)) then
            if slickmath.withinRange(u, 0, 1, self.epsilon) and u < minS then
                minS = u
                minSIndex = i
            end

            if slickmath.withinRange(v, 0, 1, self.epsilon) and v < minS then
                minS = v
                minSIndex = i
            end

            polygonInsideCircle = true
        else
            n:multiplyScalar(-circleShape.radius, _cachedCirclePolygonSegmentNormal)

            _cachedCirclePolygonSegment.a:add(_cachedCirclePolygonSegmentNormal, _cachedCirclePolygonSegment.a)
            _cachedCirclePolygonSegment.b:add(_cachedCirclePolygonSegmentNormal, _cachedCirclePolygonSegment.b)

            local didIntersect = false
            local intersection, _, _, u, v = slickmath.intersection(_cachedCircleProjectedSegment.a, _cachedCircleProjectedSegment.b, _cachedCirclePolygonSegment.a, _cachedCirclePolygonSegment.b, self.epsilon)
            if intersection and u and v and ((slickmath.withinRange(u, 0, 1, self.epsilon)) or (slickmath.withinRange(v, 0, 1, self.epsilon))) then
                didIntersect = true

                if slickmath.withinRange(u, 0, 1, self.epsilon) then
                    if u < minT then
                        minT = u
                        minTIndex = i
                    end
                end
            end

            intersection, u, v = slickmath.lineCircleIntersection(_cachedCircleProjectedSegment, a, circleShape.radius, self.epsilon)
            if intersection and u and v and ((slickmath.withinRange(u, 0, 1, self.epsilon)) or (slickmath.withinRange(v, 0, 1, self.epsilon))) then
                didIntersect = true

                if slickmath.withinRange(u, 0, 1, self.epsilon) then
                    if u < minT then
                        minT = u
                        minTIndex = i
                    end
                end

                if u > maxT then
                    maxT = u
                end
                
                if slickmath.withinRange(v, 0, 1, self.epsilon) then
                    if v < minT then
                        minT = v
                        minTIndex = i
                    end
                end

                if v > maxT then
                    maxT = v
                end
            end

            if not didIntersect then
                local distance = _cachedCirclePolygonSegment:distance(_cachedCircleCenter)
                if distance < self.epsilon then
                    if minS > 0 then
                        minS = 0
                        minSIndex = i
                    end
                end
            end
        end
    end

    if (minT == math.huge and minS > self.epsilon and circleInsidePolygon) or (polygonInsideCircle and minD < circleRadiusSquared + self.epsilon) then
        local maxDistanceFromEdge = math.sqrt(maxD)
        local minDistanceFromEdge = math.sqrt(minD)

        if circleInsidePolygon then
            local depth = minDistanceFromEdge + circleShape.radius

            local n = polygonShape.normals[minDIndex]
            _cachedCirclePolygonNormal:init(n.x, n.y)
            _cachedCirclePolygonNormal:multiplyScalar(depth, circleBumpOffset)

            if circleShape == selfShape or not polygonInsideCircle then
                self.depth = depth
                self.normal:init(_cachedCirclePolygonNormal.x, _cachedCirclePolygonNormal.y)
            end
        end

        if polygonInsideCircle then
            _cachedCirclePolygonSegment:init(
                polygonShape.vertices[minDIndex],
                polygonShape.vertices[slickmath.wrap(minDIndex, 1, polygonShape.vertexCount)])
            _cachedCirclePolygonSegment.a:add(polygonOffset, _cachedCirclePolygonSegment.a)
            _cachedCirclePolygonSegment.b:add(polygonOffset, _cachedCirclePolygonSegment.b)

            _cachedCirclePolygonSegment:project(_cachedCircleCenter, _cachedCirclePolygonProjectedPoint)
            _cachedCirclePolygonProjectedPoint:direction(_cachedCircleCenter, _cachedCirclePolygonNormal)
            _cachedCirclePolygonNormal:normalize(_cachedCirclePolygonNormal)
            local isInExactCenter = _cachedCirclePolygonNormal:lengthSquared() == 0

            local distanceFromProjectedPoint = _cachedCirclePolygonProjectedPoint:distance(_cachedCircleCenter)
            local depth = circleShape.radius - distanceFromProjectedPoint
            if circleInsidePolygon and not isInExactCenter and maxDistanceFromEdge < circleShape.radius then
                local distanceFromEdge = minDistanceFromEdge + maxDistanceFromEdge
                depth = depth + distanceFromEdge
            end

            if isInExactCenter then
                _cachedCirclePolygonNormal:init(0, 1)
            end

            _cachedCirclePolygonNormal:multiplyScalar(-depth, polygonBumpOffset)
            
            if polygonShape == selfShape then
                self.depth = depth
                self.normal:init(_cachedCirclePolygonNormal.x, _cachedCirclePolygonNormal.y)
            elseif circleShape == selfShape and not circleInsidePolygon then
                _cachedCirclePolygonNormal:multiplyScalar(depth, circleBumpOffset)
                self.depth = depth
                self.normal:init(_cachedCirclePolygonNormal.x, _cachedCirclePolygonNormal.y)
            end
        end

        if self.depth > self.epsilon then
            self.time = 0
            self.collision = true
            return
        elseif polygonShape == selfShape and polygonInsideCircle then
            _cachedCirclePolygonRelativeVelocity:normalize(_cachedCirclePolygonRelativeVelocityDirection)
            local velocityDotNormal = _cachedCirclePolygonRelativeVelocityDirection:dot(self.normal)
            if not (velocityDotNormal >= -self.epsilon and _cachedCirclePolygonRelativeVelocityDirection:lengthSquared() > 0) then
                self.time = 0
                self.collision = true
                return
            end
        end
    end

    if minT == math.huge and minS == math.huge then
        self:_clear()
        return
    end

    local index = minTIndex or minSIndex
    if minT == math.huge then
        minT = 0
    end

    if minT < 0 then
        minT = 0
    elseif minT > 1 then
        minT = 1
    end

    self.time = minT

    circleVelocity:multiplyScalar(self.time, _cachedCircleVelocity)
    _cachedCircleCenter:add(_cachedCircleVelocity, _cachedCircleOffsetCenter)

    polygonVelocity:multiplyScalar(self.time, _cachedPolygonOffset)
    polygonOffset:add(_cachedPolygonOffset, _cachedPolygonOffset)

    local indexI = slickmath.wrap(index, -1, polygonShape.vertexCount)
    local indexJ = index
    local indexK = slickmath.wrap(index, 1, polygonShape.vertexCount)

    local distanceIJ = self:_tryAddCirclePolygonContactPoint(indexI, indexJ, polygonShape, _cachedCircleOffsetCenter, circleShape.radius, _cachedPolygonOffset)
    local distanceJK = self:_tryAddCirclePolygonContactPoint(indexJ, indexK, polygonShape, _cachedCircleOffsetCenter, circleShape.radius, _cachedPolygonOffset)

    if self.contactPointsCount == 0 then
        local closestDistance = math.huge
        local closestIndex
        for i = math.min(indexI, indexJ, indexK), math.max(indexI, indexJ, indexK) do
            polygonShape.vertices[i]:add(_cachedPolygonOffset, _cachedCircleClosestPoint)
            local distanceSquared = _cachedCircleClosestPoint:distanceSquared(_cachedCircleOffsetCenter)
            if distanceSquared < closestDistance then
                closestDistance = distanceSquared
                closestIndex = i
            end
        end

        local v = polygonShape.vertices[closestIndex]
        self:_addContactPoint(v.x, v.y)
    end

    local minVertexDistance = math.huge
    local minVertexIndex
    for i = math.min(indexI, indexJ, indexK), math.max(indexI, indexJ, indexK) do
        local p = polygonShape.vertices[i]

        local distance = p:distanceSquared(_cachedCircleOffsetCenter)
        if distance < minVertexDistance then
            minVertexDistance = distance
            minVertexIndex = i
        end
    end

    local indexA, indexB
    local distanceFromSegment
    if distanceIJ < distanceJK then
        indexA = indexI
        indexB = indexJ
        distanceFromSegment = distanceIJ
    else
        indexA = indexJ
        indexB = indexK
        distanceFromSegment = distanceJK
    end

    local a = polygonShape.vertices[indexA]
    local b = polygonShape.vertices[indexB]

    local segmentNormal = polygonShape.normals[indexA]
    self.normal:init(segmentNormal.x, segmentNormal.y)
    self.normal:negate(self.normal)
    self.segment:init(a, b)

    local moved = false
    if distanceFromSegment < circleRadiusSquared then
        local distanceDifference = circleShape.radius - math.sqrt(distanceFromSegment)
        if distanceDifference > self.epsilon then
            self.normal:multiplyScalar(distanceDifference, circleBumpOffset)
            moved = true
        end
    end
    
    self.segment:project(_cachedCircleOffsetCenter, _cachedCirclePolygonProjectedSegment)
    self.segment:projectLine(_cachedCircleOffsetCenter, _cachedCirclePolygonProjectedLine)
    local projectionDistance = _cachedCirclePolygonProjectedSegment:distanceSquared(_cachedCirclePolygonProjectedLine)
    if projectionDistance > 0 then
        self.normal:multiplyScalar(-circleShape.radius, _cachedCirclePolygonProjectedLineOffset)
        _cachedCirclePolygonProjectedLineOffset:add(_cachedCirclePolygonProjectedLine, _cachedCirclePolygonProjectedLineOffset)

        local projectedPointOnLineDistanceFromVertex = _cachedCirclePolygonProjectedLineOffset:distanceSquared(polygonShape.vertices[minVertexIndex])
        local circleCenterDistanceFromVertex = minVertexDistance
        if circleCenterDistanceFromVertex < projectedPointOnLineDistanceFromVertex then
            local a = polygonShape.vertices[minVertexIndex]
            local b = _cachedCircleOffsetCenter
            self.segment:init(a, b)
            
            a:direction(b, self.normal)
            self.normal:normalize(self.normal)
        end
    end

    if self.time < self.epsilon and not moved then
        _cachedCirclePolygonRelativeVelocity:normalize(_cachedCirclePolygonRelativeVelocityDirection)
        local velocityDotNormal = _cachedCirclePolygonRelativeVelocityDirection:dot(self.normal)
        if velocityDotNormal >= -self.epsilon and _cachedCirclePolygonRelativeVelocityDirection:lengthSquared() > 0 then
            self:_clear()
            return
        end
    end

    self.collision = true
end

local _cachedCirclePointPosition = point.new()
local _cachedCirclePointVelocity = point.new()
local _cachedCirclePointSegment = segment.new()
local _cachedCircleSelfPosition = point.new()
local _cachedCircleOtherPosition = point.new()
local _cachedCircleContactPoint1 = point.new()
local _cachedCircleContactPoint2 = point.new()
local _cachedCircleRelativeVelocityDirection = point.new()
local _cachedCirclePenetratingOffset = point.new()
local _cachedCircleSelfOtherDirection = point.new()

--- @private
--- @param selfShape slick.collision.circle
--- @param otherShape slick.collision.circle
--- @param selfOffset slick.geometry.point
--- @param otherOffset slick.geometry.point
--- @param selfVelocity slick.geometry.point
--- @param otherVelocity slick.geometry.point
function shapeCollisionResolutionQuery:_performCircleCircleProjection(selfShape, otherShape, selfOffset, otherOffset, selfVelocity, otherVelocity)
    selfShape.center:add(selfOffset, _cachedCircleSelfPosition)
    otherShape.center:add(otherOffset, _cachedCircleOtherPosition)

    _cachedCircleOtherPosition:sub(_cachedCircleSelfPosition, _cachedCirclePointPosition)
    selfVelocity:sub(otherVelocity, _cachedCirclePointVelocity)

    otherVelocity:direction(selfVelocity, _cachedCirclePointVelocity)

    _cachedCirclePointSegment.a:init(_cachedCircleSelfPosition.x, _cachedCircleSelfPosition.y)
    _cachedCirclePointSegment.a:add(_cachedCirclePointVelocity, _cachedCirclePointSegment.b)

    local combinedCircleRadius = selfShape.radius + otherShape.radius

    local distance = _cachedCircleSelfPosition:distance(_cachedCircleOtherPosition)
    if distance < combinedCircleRadius - self.epsilon then
        self.depth = combinedCircleRadius - distance
        _cachedCircleOtherPosition:direction(_cachedCircleSelfPosition, self.normal)
        self.normal:normalize(self.normal)

        if self.normal:lengthSquared() == 0 then
            self.normal:init(0, 1)
        end

        self.normal:multiplyScalar(self.depth, self.currentOffset)
        self.normal:multiplyScalar(-self.depth, self.otherOffset)

        self.time = 0
        self.collision = true

        return
    end

    local willCollide, u, v = slickmath.lineCircleIntersection(_cachedCirclePointSegment, _cachedCircleOtherPosition, selfShape.radius + otherShape.radius, self.epsilon)
    if willCollide and u and v and (slickmath.withinRange(u, 0, 1, self.epsilon) or slickmath.withinRange(v, 0, 1, self.epsilon)) then
        self.depth = 0

        self.firstTime = math.min(u, v)
        self.lastTime = math.max(u, v)

        if slickmath.withinRange(u, 0, 1, self.epsilon) and slickmath.withinRange(v, 0, 1, self.epsilon) then
            self.time = math.min(u, v)
        elseif slickmath.withinRange(u, 0, 1, self.epsilon) then
            self.time = u
        else
            self.time = v
        end

        selfVelocity:multiplyScalar(self.time, self.currentOffset)
        otherVelocity:multiplyScalar(self.time, self.otherOffset)
    else
        willCollide = false
    end

    local intersection, r1x, r1y, r2x, r2y = slickmath.circleCircleIntersection(
        _cachedCircleSelfPosition, selfShape.radius,
        _cachedCircleOtherPosition, otherShape.radius)

    if intersection or willCollide then
        if r1x and r1y and r2x and r2y then
            _cachedCircleContactPoint1:init(r1x, r1y)
            _cachedCircleContactPoint2:init(r2x, r2y)

            if _cachedCircleContactPoint1:distance(_cachedCircleContactPoint2) > 0 then
                self:_addContactPoint(_cachedCircleContactPoint1.x, _cachedCircleContactPoint1.y)
                self:_addContactPoint(_cachedCircleContactPoint2.x, _cachedCircleContactPoint2.y)
            else
                self:_addContactPoint(_cachedCircleContactPoint1.x, _cachedCircleContactPoint1.y)
            end
        end

        _cachedCircleOtherPosition:direction(_cachedCircleSelfPosition, self.normal)

        local distance = self.normal:length()
        if distance > 0 then
            self.collision = true
            self.normal:divideScalar(distance, self.normal)
        end

        self.depth = (selfShape.radius + otherShape.radius) - _cachedCircleSelfPosition:distance(_cachedCircleOtherPosition)

        if not (r1x and r1y and r2x and r2y) and not willCollide then
            self.normal:multiplyScalar(self.depth, _cachedCirclePenetratingOffset)

            self.currentOffset:sub(_cachedCirclePenetratingOffset, self.currentOffset)
            self.otherOffset:add(_cachedCirclePenetratingOffset, self.otherOffset)
        end
    end

    if not self.collision then
        self:_clear()
        return
    end

    if self.time < self.epsilon and _cachedCirclePointVelocity:lengthSquared() > 0 then
        _cachedCircleSelfPosition:direction(_cachedCircleOtherPosition, _cachedCircleSelfOtherDirection)
        _cachedCircleSelfOtherDirection:normalize(_cachedCircleSelfOtherDirection)
        _cachedCirclePointVelocity:normalize(_cachedCircleRelativeVelocityDirection)

        local dot = _cachedCircleRelativeVelocityDirection:dot(self.normal)
        if dot > -self.epsilon then
            self.collision = false
            self:_clear()
            return
        end
    end

    self.collision = true
end

local _cachedRelativeVelocity = point.new()
local _cachedSelfFutureCenter = point.new()
local _cachedSelfVelocityMinusOffset = point.new()
local _cachedDirection = point.new()
local _cachedSelfVelocityDirection = point.new()
local _cachedOtherVelocityDirection = point.new()
local _cachedSelfShapeCenter = point.new()
local _cachedOtherShapeCenter = point.new()

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
    
    self.depth = math.huge
    
    local hit = true
    local side = SIDE_NONE
    
    local currentInterval = self.currentShape.currentInterval
    local otherInterval = self.otherShape.currentInterval

    local isTouching = true
    if _cachedRelativeVelocity:lengthSquared() == 0 then
        for i = 1, self.currentShape.axesCount + self.otherShape.axesCount do
            local axis = self:_getAxis(i)

            currentInterval:init()
            otherInterval:init()

            self:_handleAxis(axis)

            if self:_compareIntervals(axis) then
                isTouching = true
                hit = true
            else
                hit = false
                isTouching = false
                break
            end
        end

        if hit and isTouching and self.depth < self.epsilon then
            self:_clear()
            return
        end
    else
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

    if isTouching and self.depth < self.epsilon then
        isTouching = false
    end

    if not hit and isTouching then
        hit = true
    end

    if not isTouching then
        self.depth = 0
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

    if hit and not isTouching and self.firstTime <= 0 and self.depth < math.huge then
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
        
        local areShapesMovingApart = selfSpeed == 0 or otherSpeed == 0 or _cachedSelfVelocityDirection:dot(_cachedOtherVelocityDirection) <= self.epsilon
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
            selfShape.vertices[currentInterval.indices[currentInterval.minIndex].index]:add(self.currentOffset, _cachedSegmentA.a)
            selfShape.vertices[currentInterval.indices[currentInterval.minIndex + 1].index]:add(self.currentOffset, _cachedSegmentA.b)

            otherShape.vertices[otherInterval.indices[otherInterval.maxIndex - 1].index]:add(self.otherOffset, _cachedSegmentB.a)
            otherShape.vertices[otherInterval.indices[otherInterval.maxIndex].index]:add(self.otherOffset, _cachedSegmentB.b)
            _cachedSegmentB.a:direction(_cachedSegmentB.b, self.normal)
        elseif side == SIDE_RIGHT then
            otherShape.vertices[otherInterval.indices[otherInterval.minIndex].index]:add(self.otherOffset, _cachedSegmentA.a)
            otherShape.vertices[otherInterval.indices[otherInterval.minIndex + 1].index]:add(self.otherOffset, _cachedSegmentA.b)
            _cachedSegmentA.a:direction(_cachedSegmentA.b, self.normal)

            selfShape.vertices[currentInterval.indices[currentInterval.maxIndex - 1].index]:add(self.currentOffset, _cachedSegmentB.a)
            selfShape.vertices[currentInterval.indices[currentInterval.maxIndex].index]:add(self.currentOffset, _cachedSegmentB.b)
        end
        
        self.normal:normalize(self.normal)
        self.normal:right(self.normal)

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

local _cachedProjectCircleBumpOffset = point.new()
local _cachedProjectPolygonBumpOffset = point.new()
local _cachedProjectScaledVelocity = point.new()

--- @param selfShape slick.collision.shapeInterface
--- @param otherShape slick.collision.shapeInterface
--- @param selfOffset slick.geometry.point
--- @param otherOffset slick.geometry.point
--- @param selfVelocity slick.geometry.point
--- @param otherVelocity slick.geometry.point
function shapeCollisionResolutionQuery:performProjection(selfShape, otherShape, selfOffset, otherOffset, selfVelocity, otherVelocity)
    self:_beginQuery()

    if util.is(selfShape, circle) and util.is(otherShape, circle) then
        --- @cast selfShape slick.collision.circle
        --- @cast otherShape slick.collision.circle
        self:_performCircleCircleProjection(selfShape, otherShape, selfOffset, otherOffset, selfVelocity, otherVelocity)
    elseif util.is(selfShape, circle) then
        --- @cast selfShape slick.collision.circle
        _cachedProjectCircleBumpOffset:init(0, 0)
        _cachedProjectPolygonBumpOffset:init(0, 0)
        self:_performCirclePolygonProjection(selfShape, otherShape, selfOffset, otherOffset, selfVelocity, otherVelocity, _cachedProjectCircleBumpOffset, _cachedProjectPolygonBumpOffset, selfShape)
        if self.collision then
            self.currentOffset:add(_cachedProjectCircleBumpOffset, self.currentOffset)
            self.otherOffset:add(_cachedProjectPolygonBumpOffset, self.otherOffset)
            
            selfVelocity:multiplyScalar(self.time, _cachedProjectScaledVelocity)
            _cachedProjectScaledVelocity:add(self.currentOffset, self.currentOffset)
            
            otherVelocity:multiplyScalar(self.time, _cachedProjectScaledVelocity)
            _cachedProjectScaledVelocity:add(self.otherOffset, self.otherOffset)
        end
    elseif util.is(otherShape, circle) then
        --- @cast otherShape slick.collision.circle
        _cachedProjectCircleBumpOffset:init(0, 0)
        _cachedProjectPolygonBumpOffset:init(0, 0)
        self:_performCirclePolygonProjection(otherShape, selfShape, otherOffset, selfOffset, otherVelocity, selfVelocity, _cachedProjectCircleBumpOffset, _cachedProjectPolygonBumpOffset, selfShape)
        if self.collision then
            self.currentOffset:add(_cachedProjectPolygonBumpOffset, self.currentOffset)
            self.otherOffset:add(_cachedProjectCircleBumpOffset, self.otherOffset)

            selfVelocity:multiplyScalar(self.time, _cachedProjectScaledVelocity)
            _cachedProjectScaledVelocity:add(self.currentOffset, self.currentOffset)
            
            self.otherOffset:add(_cachedProjectCircleBumpOffset, self.otherOffset)
            otherVelocity:multiplyScalar(self.time, _cachedProjectScaledVelocity)
        end
    else
        self:_performPolygonPolygonProjection(selfShape, otherShape, selfOffset, otherOffset, selfVelocity, otherVelocity)
    end

    if self.collision then
        self.normal:round(self.epsilon)
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
    self.segment.a:init(0, 0)
    self.segment.b:init(0, 0)
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
    if otherInterval.max <= selfInterval.min + self.epsilon then
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
    elseif selfInterval.max <= otherInterval.min + self.epsilon then
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
    if util.is(self.otherShape.shape, circle) then
        local c = self.otherShape.shape

        _cachedGetAxesCircleCenter:init(c.center.x, c.center.y)
        c.center:add(self.otherShape.offset, _cachedGetAxesCircleCenter)

        --- @cast c slick.collision.circle
        local closest = self:getClosestVertex(self.currentShape.shape, _cachedGetAxesCircleCenter)

        if closest then
            local axis = self:addAxis()

            closest:direction(_cachedGetAxesCircleCenter, axis.normal)
            axis.normal:normalize(axis.normal)
            axis.segment:init(_cachedGetAxesCircleCenter, closest)
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
