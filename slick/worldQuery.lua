local worldQueryResponse = require("slick.worldQueryResponse")
local quadTreeQuery = require("slick.collision.quadTreeQuery")
local shapeCollisionResolutionQuery = require("slick.collision.shapeCollisionResolutionQuery")
local point = require("slick.geometry.point")
local rectangle = require("slick.geometry.rectangle")
local transform = require("slick.geometry.transform")
local slicktable = require("slick.util.slicktable")

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

local _cachedPosition = point.new()
local _cachedSelfVelocity = point.new()
local _cachedOtherVelocity = point.new()

--- @param entity slick.entity
--- @param x number
--- @param y number
--- @param filter slick.worldFilterQueryFunc
function worldQuery:perform(entity, x, y, filter)
    self:_beginQuery(entity, x, y)

    _cachedPosition:init(entity.transform.x, entity.transform.y)
    _cachedSelfVelocity:init(x, y)
    _cachedPosition:direction(_cachedSelfVelocity, _cachedSelfVelocity)

    for _, otherShape in ipairs(self.quadTreeQuery.results) do
        --- @cast otherShape slick.collision.shapeInterface
        if otherShape.entity ~= entity and otherShape.bounds:overlaps(entity.bounds) then
            for _, shape in ipairs(entity.shapes.shapes) do
                if shape.bounds:overlaps(otherShape.bounds) then
                    local response = filter(entity.item, otherShape.entity.item, shape, otherShape)

                    if response then
                        self.collisionQuery:perform(shape, otherShape, _cachedSelfVelocity, _cachedOtherVelocity)
                        if self.collisionQuery.collision then
                            self:_addCollision(shape, otherShape, response)
                        end
                    end
                end
            end
        end
    end

    self:_endQuery()
end

local _cachedTransform = transform.new()
local _cachedTopLeft = point.new()
local _cachedTopRight = point.new()
local _cachedBottomLeft = point.new()
local _cachedBottomRight = point.new()
local _cachedBounds = rectangle.new()

function worldQuery:reset()
    slicktable.clear(self.results)
end

--- @private
--- @param entity slick.entity
--- @param x number
--- @param y number
function worldQuery:_beginQuery(entity, x, y)
    self:reset()

    entity.transform:copy(_cachedTransform)
    _cachedTransform:setTransform(_cachedTransform.x + x, _cachedTransform.y + y)

    _cachedTopLeft:init(_cachedTransform:transformPoint(entity.bounds:left(), entity.bounds:top()))
    _cachedTopRight:init(_cachedTransform:transformPoint(entity.bounds:right(), entity.bounds:top()))
    _cachedBottomRight:init(_cachedTransform:transformPoint(entity.bounds:left(), entity.bounds:bottom()))
    _cachedBottomLeft:init(_cachedTransform:transformPoint(entity.bounds:right(), entity.bounds:bottom()))

    _cachedBounds:init(_cachedTopLeft.x, _cachedTopLeft.y, _cachedTopLeft.x, _cachedTopLeft.x)
    _cachedBounds:expand(_cachedTopRight.x, _cachedTopRight.y)
    _cachedBounds:expand(_cachedBottomLeft.x, _cachedBottomLeft.y)
    _cachedBounds:expand(_cachedBottomRight.x, _cachedBottomRight.y)

    _cachedBounds:expand(entity.bounds:left(), entity.bounds:top())
    _cachedBounds:expand(entity.bounds:right(), entity.bounds:bottom())

    self.quadTreeQuery:perform(_cachedBounds)
end

--- @private
function worldQuery:_endQuery()
    table.sort(self.results, worldQueryResponse.less)
end

--- @private
--- @param shape slick.collision.shapeInterface
--- @param otherShape slick.collision.shapeInterface
--- @param response string
function worldQuery:_addCollision(shape, otherShape, response)
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
