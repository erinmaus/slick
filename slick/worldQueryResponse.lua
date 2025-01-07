local point = require("slick.geometry.point")
local slicktable = require("slick.util.slicktable")
local segment = require("slick.geometry.segment")

--- @class slick.worldQueryResponse
--- @field query slick.worldQuery
--- @field response string | slick.worldVisitFunc | true
--- @field item any
--- @field entity slick.entity
--- @field shape slick.collision.shape
--- @field other any?
--- @field otherEntity slick.entity?
--- @field otherShape slick.collision.shape?
--- @field normal slick.geometry.point
--- @field depth number
--- @field time number
--- @field offset slick.geometry.point
--- @field touch slick.geometry.point
--- @field isProjection boolean
--- @field contactPoint slick.geometry.point
--- @field contactPoints slick.geometry.point[]
--- @field segment slick.geometry.segment
--- @field distance number
--- @field extra table
--- @field private contactPointsCache slick.geometry.point[]
local worldQueryResponse = {}
local metatable = { __index = worldQueryResponse }

--- @return slick.worldQueryResponse
function worldQueryResponse.new(query)
    return setmetatable({
        query = query,
        response = "slide",
        normal = point.new(),
        depth = 0,
        time = 0,
        offset = point.new(),
        touch = point.new(),
        isProjection = false,
        contactPoint = point.new(),
        contactPoints = {},
        segment = segment.new(),
        extra = {},
        contactPointsCache = { point.new() },
    }, metatable)
end

--- @param a slick.worldQueryResponse
--- @param b slick.worldQueryResponse
function worldQueryResponse.less(a, b)
    if a.time == b.time then
        if a.depth == b.depth then
            return a.distance < b.distance
        else
            return a.depth > b.depth
        end
    end

    return a.time < b.time
end

local _cachedInitItemPosition = point.new()

--- @param shape slick.collision.shapeInterface
--- @param otherShape slick.collision.shapeInterface?
--- @param response string | slick.worldVisitFunc | true
--- @param position slick.geometry.point
--- @param query slick.collision.shapeCollisionResolutionQuery
function worldQueryResponse:init(shape, otherShape, response, position, query)
    self.response = response

    self.shape = shape
    self.entity = shape.entity
    self.item = shape.entity.item

    self.otherShape = otherShape
    self.otherEntity = self.otherShape and self.otherShape.entity
    self.other = self.otherEntity and self.otherEntity.item

    self.normal:init(query.normal.x, query.normal.y)
    self.depth = query.depth
    self.time = query.time

    self.offset:init(query.currentOffset.x, query.currentOffset.y)
    position:add(self.offset, self.touch)

    local closestContactPointDistance = math.huge

    --- @type slick.geometry.point
    local closestContactPoint

    _cachedInitItemPosition:init(self.entity.transform.x, self.entity.transform.y)

    slicktable.clear(self.contactPoints)
    for i = 1, query.contactPointsCount do
        local inputContactPoint = query.contactPoints[i]
        local outputContactPoint = self.contactPointsCache[i]
        if not outputContactPoint then
            outputContactPoint = point.new()
            self.contactPointsCache[i] = outputContactPoint
        end

        outputContactPoint:init(inputContactPoint.x, inputContactPoint.y)
        table.insert(self.contactPoints, outputContactPoint)

        local distanceSquared = outputContactPoint:distance(_cachedInitItemPosition)
        if distanceSquared < closestContactPointDistance then
            closestContactPointDistance = distanceSquared
            closestContactPoint = outputContactPoint
        end
    end

    if closestContactPoint then
        self.contactPoint:init(closestContactPoint.x, closestContactPoint.y)
    else
        self.contactPoint:init(0, 0)
    end

    self.distance = self.shape:distance(self.touch)
    self.segment:init(query.segment.a, query.segment.b)

    slicktable.clear(self.extra)
end

function worldQueryResponse:isTouchingWillNotPenetrate()
    return self.time == 0 and self.depth == 0
end

function worldQueryResponse:isTouchingWillPenetrate()
    return self.time == 0 and (self.isProjection and self.depth >= 0 or self.depth > 0)
end

function worldQueryResponse:notTouchingWillTouch()
    return self.time > 0
end

--- @param other slick.worldQueryResponse
function worldQueryResponse:move(other)
    other.response = self.response

    other.shape = self.shape
    other.entity = self.entity
    other.item = self.item

    other.otherShape = self.otherShape
    other.otherEntity = self.otherEntity
    other.other = self.other

    other.normal:init(self.normal.x, self.normal.y)
    other.depth = self.depth
    other.time = self.time
    other.offset:init(self.offset.x, self.offset.y)
    other.touch:init(self.touch.x, self.touch.y)
    other.isProjection = self.isProjection
    
    other.contactPoint:init(self.contactPoint.x, self.contactPoint.y)
    other.distance = self.distance
    other.segment:init(self.segment.a, self.segment.b)
    
    slicktable.clear(other.contactPoints)
    for i, inputContactPoint in ipairs(self.contactPoints) do
        local outputContactPoint = other.contactPointsCache[i]
        if not outputContactPoint then
            outputContactPoint = point.new()
            other.contactPointsCache[i] = outputContactPoint
        end
        
        outputContactPoint:init(inputContactPoint.x, inputContactPoint.y)
    end
    
    other.extra, self.extra = self.extra, other.extra
end

return worldQueryResponse
