local point = require("slick.geometry.point")
local slicktable = require("slick.util.slicktable")

--- @class slick.worldQueryResponse
--- @field response string
--- @field item any
--- @field entity slick.entity
--- @field shape slick.collision.shape
--- @field other any
--- @field otherEntity slick.entity
--- @field otherShape slick.collision.shape
--- @field normal slick.geometry.point
--- @field depth number
--- @field time number
--- @field offset slick.geometry.point
--- @field contactPoint slick.geometry.point
--- @field contactPoints slick.geometry.point[]
--- @field extra table
--- @field private contactPointsCache slick.geometry.point[]
local worldQueryResponse = {}
local metatable = { __index = worldQueryResponse }

--- @return slick.worldQueryResponse
function worldQueryResponse.new()
    return setmetatable({
        response = "slide",
        normal = point.new(),
        depth = 0,
        time = 0,
        offset = point.new(),
        contactPoint = point.new(),
        contactPoints = {},
        extra = {},
        contactPointsCache = { point.new() },
    }, metatable)
end

--- @param a slick.worldQueryResponse
--- @param b slick.worldQueryResponse
function worldQueryResponse.less(a, b)
    return a.distance < b.distance
end

local _cachedInitItemPosition = point.new()

--- @param shape slick.collision.shapeInterface
--- @param otherShape slick.collision.shapeInterface
--- @param response string
--- @param query slick.collision.shapeCollisionResolutionQuery
function worldQueryResponse:init(shape, otherShape, response, query)
    self.response = response

    self.shape = shape
    self.entity = shape.entity
    self.item = shape.entity.item

    self.otherShape = otherShape
    self.otherEntity = otherShape.entity
    self.other = otherShape.entity.item

    self.normal:init(query.normal.x, query.normal.y)
    self.depth = query.depth
    self.time = query.time
    self.offset:init(query.currentOffset.x, query.currentOffset.y)

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
        table.insert(self.contactPoints, inputContactPoint)

        local distanceSquared = outputContactPoint:distance(_cachedInitItemPosition)
        if distanceSquared < closestContactPointDistance then
            closestContactPointDistance = distanceSquared
            closestContactPoint = outputContactPoint
        end
    end

    if closestContactPoint then
        self.contactPoint:init(closestContactPoint.x, closestContactPoint.y)
        self.distance = self.shape:distance(self.contactPoint)
    else
        self.contactPoint:init()
        self.distance = math.huge
    end

    slicktable.clear(self.extra)
end

--- @param other slick.worldQueryResponse
function worldQueryResponse:move(other)
    other.response = self.response

    other.shape = self.shape
    other.entity = self.entity
    other.item = self.item

    other.otherShape = self.shape
    other.otherEntity = self.entity
    other.other = self.item

    other.normal:init(self.normal.x, self.normal.y)
    other.depth = self.depth
    other.time = self.time
    other.offset:init(self.offset.x, self.offset.y)

    other.contactPoint:init(self.contactPoint.x, self.contactPoint.y)
    other.distance = self.distance

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
