local worldQueryResponse = require("slick.worldQueryResponse")
local box = require("slick.collision.box")
local lineSegment = require("slick.collision.lineSegment")
local quadTreeQuery = require("slick.collision.quadTreeQuery")
local ray = require("slick.geometry.ray")
local shapeCollisionResolutionQuery = require("slick.collision.shapeCollisionResolutionQuery")
local point = require("slick.geometry.point")
local rectangle = require("slick.geometry.rectangle")
local transform = require("slick.geometry.transform")
local slicktable = require("slick.util.slicktable")
local util = require("slick.util")
local segment = require("slick.geometry.segment")

--- @class slick.worldQuery
--- @field world slick.world
--- @field quadTreeQuery slick.collision.quadTreeQuery
--- @field results slick.worldQueryResponse[]
--- @field private cachedResults slick.worldQueryResponse[]
--- @field private collisionQuery slick.collision.shapeCollisionResolutionQuery
local worldQuery = {}
local metatable = { __index = worldQuery }

--- @param world slick.world
--- @return slick.worldQuery
function worldQuery.new(world)
    return setmetatable({
        world = world,
        quadTreeQuery = quadTreeQuery.new(world.quadTree),
        results = {},
        cachedResults = {},
        collisionQuery = shapeCollisionResolutionQuery.new()
    }, metatable)
end

local _cachedQueryTransform = transform.new()
local _cachedQueryBoxShape = box.new(nil, 0, 0, 1, 1)
local _cachedQueryLineSegmentShape = lineSegment.new(nil, 0, 0, 1, 1)
local _cachedQueryVelocity = point.new()

--- @private
--- @param shape slick.collision.shapeInterface
--- @param filter slick.worldShapeFilterQueryFunc
function worldQuery:_performShapeQuery(shape, filter)
    for _, otherShape in ipairs(self.quadTreeQuery.results) do
        --- @cast otherShape slick.collision.shapeInterface
        local response = filter(otherShape.entity.item, otherShape)

        if response then
            self.collisionQuery:perform(shape, otherShape, _cachedQueryVelocity, _cachedQueryVelocity, false)

            if self.collisionQuery.collision then
                self:_addCollision(otherShape, nil, response, true)
            end
        end
    end
end

--- @private
--- @param p slick.geometry.point
--- @param filter slick.worldShapeFilterQueryFunc
function worldQuery:_performPrimitivePointQuery(p, filter)
    self.collisionQuery:reset()

    for _, otherShape in ipairs(self.quadTreeQuery.results) do
        --- @cast otherShape slick.collision.shapeInterface
        local response = filter(otherShape.entity.item, otherShape)
        if response then
            local inside = otherShape:inside(p)
            if inside then
                self:_addCollision(otherShape, nil, response, true)
            end
        end
    end
end

--- @private
--- @param r slick.geometry.ray
--- @param filter slick.worldShapeFilterQueryFunc
function worldQuery:_performPrimitiveRayQuery(r, filter)
    self.collisionQuery:reset()

    for _, otherShape in ipairs(self.quadTreeQuery.results) do
        --- @cast otherShape slick.collision.shapeInterface
        local response = filter(otherShape.entity.item, otherShape)
        if response then
            local inside, x, y = otherShape:raycast(r)
            if inside and x and y then
                self:_addCollision(otherShape, nil, response, true)

                local result = self.results[#self.results]
                result.contactPoint:init(x, y)
            end
        end
    end
end

--- @private
--- @param r slick.geometry.rectangle
--- @param filter slick.worldShapeFilterQueryFunc
function worldQuery:_performPrimitiveRectangleQuery(r, filter)
    _cachedQueryTransform:setTransform(r:left(), r:top(), 0, r:width(), r:height())
    _cachedQueryBoxShape:transform(_cachedQueryTransform)

    self:_performShapeQuery(_cachedQueryBoxShape, filter)
end

--- @private
--- @param s slick.geometry.segment
--- @param filter slick.worldShapeFilterQueryFunc
function worldQuery:_performPrimitiveSegmentQuery(s, filter)
    _cachedQueryLineSegmentShape:init(s.a.x, s.a.y, s.b.x, s.b.y)
    self:_performShapeQuery(_cachedQueryLineSegmentShape, filter)
end

--- @param shape slick.geometry.point | slick.geometry.rectangle | slick.geometry.segment | slick.geometry.ray
--- @param filter slick.worldShapeFilterQueryFunc
function worldQuery:performPrimitive(shape, filter)
    self:_beginPrimitiveQuery(shape)

    if util.is(shape, rectangle) then
        --- @cast shape slick.geometry.rectangle
        self:_performPrimitiveRectangleQuery(shape, filter)
    elseif util.is(shape, point) then
        --- @cast shape slick.geometry.point
        self:_performPrimitivePointQuery(shape, filter)
    elseif util.is(shape, segment) then
        --- @cast shape slick.geometry.segment
        self:_performPrimitiveSegmentQuery(shape, filter)
    elseif util.is(shape, ray) then
        --- @cast shape slick.geometry.ray
        self:_performPrimitiveRayQuery(shape, filter)
    end
end

local _cachedPosition = point.new()
local _cachedSelfVelocity = point.new()
local _cachedOtherVelocity = point.new()
local _cachedEntityBounds = rectangle.new()
local _cachedShapeBounds = rectangle.new()

--- @param entity slick.entity
--- @param x number
--- @param y number
--- @param filter slick.worldFilterQueryFunc
function worldQuery:perform(entity, x, y, filter)
    self:_beginQuery(entity, x, y)

    _cachedPosition:init(entity.transform.x, entity.transform.y)
    _cachedSelfVelocity:init(x, y)
    _cachedPosition:direction(_cachedSelfVelocity, _cachedSelfVelocity)

    _cachedEntityBounds:init(entity.bounds:left(), entity.bounds:top(), entity.bounds:right(), entity.bounds:bottom())
    _cachedEntityBounds:move(x - entity.transform.x, y - entity.transform.y)

    for _, otherShape in ipairs(self.quadTreeQuery.results) do
        --- @cast otherShape slick.collision.shapeInterface
        if otherShape.entity ~= entity and _cachedEntityBounds:overlaps(otherShape.bounds) then
            for _, shape in ipairs(entity.shapes.shapes) do
                _cachedShapeBounds:init(shape.bounds:left(), shape.bounds:top(), shape.bounds:right(), shape.bounds:bottom())
                if _cachedShapeBounds:overlaps(otherShape.bounds) then
                    local response = filter(entity.item, otherShape.entity.item, shape, otherShape)
                    if response then
                        self.collisionQuery:perform(shape, otherShape, _cachedSelfVelocity, _cachedOtherVelocity)
                        if self.collisionQuery.collision then
                            self:_addCollision(shape, otherShape, response, false)
                        end
                    end
                end
            end
        end
    end

    self:_endQuery()
end

function worldQuery:reset()
    slicktable.clear(self.results)
end

local _cachedBounds = rectangle.new()

--- @private
--- @param entity slick.entity
--- @param x number
--- @param y number
function worldQuery:_beginQuery(entity, x, y)
    self:reset()

    _cachedBounds:init((entity.bounds:left() - entity.transform.x) + x, (entity.bounds:top() - entity.transform.y))
    _cachedBounds:expand((entity.bounds:right() - entity.transform.x) + x, (entity.bounds:bottom() - entity.transform.y) + y)
    _cachedBounds:expand(entity.bounds:left(), entity.bounds:top())
    _cachedBounds:expand(entity.bounds:right(), entity.bounds:bottom())

    self.quadTreeQuery:perform(_cachedBounds)
end

--- @private
--- @param shape slick.geometry.point | slick.geometry.rectangle | slick.geometry.segment | slick.geometry.ray
function worldQuery:_beginPrimitiveQuery(shape)
    self:reset()
    self.quadTreeQuery:perform(shape)
end

--- @private
function worldQuery:_endQuery()
    table.sort(self.results, worldQueryResponse.less)
end

--- @private
--- @param shape slick.collision.shapeInterface
--- @param otherShape slick.collision.shapeInterface?
--- @param response string | boolean
--- @param primitive boolean
function worldQuery:_addCollision(shape, otherShape, response, primitive)
    if not primitive and not (self.collisionQuery.depth > 0 or (self.collisionQuery.time > 0 and self.collisionQuery.time <= 1)) then
        return
    end

    local index = #self.results + 1
    local result = self.cachedResults[index]
    if not result then
        result = worldQueryResponse.new()
        table.insert(self.cachedResults, result)
    end

    result:init(shape, otherShape, response, self.collisionQuery)
    table.insert(self.results, result)
end

--- @param response slick.worldQueryResponse
function worldQuery:push(response)
    local index = #self.results + 1
    local result = self.cachedResults[index]
    if not result then
        result = worldQueryResponse.new()
        table.insert(self.cachedResults, result)
    end

    response:move(result)
    table.insert(self.results, result)
end

return worldQuery
