local cache = require("slick.cache")
local quadTree = require("slick.collision.quadTree")
local entity = require("slick.entity")
local point = require("slick.geometry.point")
local ray = require("slick.geometry.ray")
local rectangle  = require("slick.geometry.rectangle")
local segment = require("slick.geometry.segment")
local transform = require("slick.geometry.transform")
local defaultOptions = require("slick.options")
local responses = require("slick.responses")
local worldQuery = require("slick.worldQuery")
local util = require("slick.util")
local slicktable = require("slick.util.slicktable")

--- @alias slick.worldFilterQueryFunc fun(item: any, other: any, shape: slick.collision.shape, otherShape: slick.collision.shape): string | false
local function defaultWorldFilterQueryFunc()
    return "slide"
end

--- @alias slick.worldShapeFilterQueryFunc fun(item: any, shape: slick.collision.shape): boolean
local function defaultWorldShapeFilterQueryFunc()
    return true
end

--- @alias slick.worldResponseFunc fun(world: slick.world, query: slick.worldQuery, response: slick.worldQueryResponse, x: number, y: number, filter: slick.worldFilterQueryFunc): number, number, slick.worldQueryResponse[], number, slick.worldQuery

--- @class slick.world
--- @field cache slick.cache
--- @field quadTree slick.collision.quadTree
--- @field private responses table<string, slick.worldResponseFunc>
--- @field private entities slick.entity[]
--- @field private itemToEntity table<any, number>
--- @field private freeList number[]
--- @field private cachedWorldQuery slick.worldQuery
local world = {}
local metatable = { __index = world }

--- @param width number
--- @param height number
--- @param options slick.options?
function world.new(width, height, options)
    assert(type(width) == "number" and width > 0, "expected width to be number > 0")
    assert(type(height) == "number" and height > 0, "expected height to be number > 0")

    options = options or defaultOptions

    local quadTreeOptions = {
        width = width,
        height = height,
        x = options.quadTreeX or defaultOptions.quadTreeX,
        y = options.quadTreeY or defaultOptions.quadTreeY,
        maxLevels = options.quadTreeMaxLevels or defaultOptions.quadTreeMaxLevels,
        maxData = options.quadTreeMaxData or defaultOptions.quadTreeMaxData,
        expand = options.quadTreeExpand == nil and defaultOptions.quadTreeExpand or options.quadTreeExpand,
    }

    local self = setmetatable({
        cache = cache.new(options),
        quadTreeOptions = quadTreeOptions,
        quadTree = quadTree.new(quadTreeOptions),
        entities = {},
        itemToEntity = {},
        freeList = {},
        visited = {},
        responses = {}
    }, metatable)

    
    self:addResponse("slide", responses.slide)
    self:addResponse("touch", responses.touch)
    self:addResponse("cross", responses.cross)

    self.cachedWorldQuery = worldQuery.new(self)

    return self
end

local _cachedTransform = transform.new()

--- @overload fun(e: slick.entity, x: number, y: number, shape: slick.collision.shapelike): slick.entity
--- @overload fun(e: slick.entity, transform: slick.geometry.transform, shape: slick.collision.shapelike): slick.entity
--- @return slick.geometry.transform, slick.collision.shapeDefinition
local function _getTransformShapes(e, a, b, c)
    if type(a) == "number" and type(b) == "number" then
        e.transform:copy(_cachedTransform)
        _cachedTransform:setTransform(a, b)

        --- @cast c slick.collision.shapeDefinition
        return _cachedTransform, c
    end

    assert(util.is(a, transform))

    --- @cast a slick.geometry.transform
    --- @cast b slick.collision.shapeDefinition
    return a, b
end

--- @param item any
--- @return slick.entity
--- @overload fun(self: slick.world, item: any, x: number, y: number, shape: slick.collision.shapeDefinition): slick.entity
--- @overload fun(self: slick.world, item: any, transform: slick.geometry.transform, shape: slick.collision.shapeDefinition): slick.entity
function world:add(item, a, b, c)
    assert(not self:has(item), "item exists in world")

    --- @type slick.entity
    local e

    --- @type number
    local i
    if #self.freeList > 0 then
        i = table.remove(self.freeList)
        e = self.entities[i]
    else
        e = entity.new()
        table.insert(self.entities, e)
        i = #self.entities
    end

    e:init(item)

    local transform, shapes = _getTransformShapes(e, a, b, c)
    e:setTransform(transform)
    e:setShapes(shapes)
    e:add(self)

    self.itemToEntity[item] = i
    return entity
end

--- @param item any
--- @return slick.entity
function world:get(item)
    return self.entities[self.itemToEntity[item]]
end

--- @param items any[]?
--- @return any[]
function world:getItems(items)
    items = items or {}
    slicktable.clear(items)

    for item in pairs(self.itemToEntity) do
        table.insert(items, item)
    end

    return items
end

function world:has(item)
    return self:get(item) ~= nil
end

--- @overload fun(self: slick.world, item: any, x: number, y: number, shape: slick.collision.shapeDefinition): slick.entity
--- @overload fun(self: slick.world, item: any, transform: slick.geometry.transform, shape: slick.collision.shapeDefinition): slick.entity
function world:update(item, a, b, c)
    local e = self:get(item)

    local transform, shapes = _getTransformShapes(e, a, b, c)
    if shapes then
        e:setShapes(shapes)
    end
    e:setTransform(transform)
end

--- @param deltaTime number
function world:frame(deltaTime)
    -- Nothing for now.
end

--- @param item any
function world:remove(item)
    local entityIndex = self.itemToEntity[item]
    local entity = self.entities[entityIndex]

    entity:detach()
    table.insert(self.freeList, entityIndex)

    return entity
end

--- @param item any
--- @param x number
--- @param y number
--- @param filter slick.worldFilterQueryFunc?
--- @param query slick.worldQuery?
--- @return slick.worldQueryResponse[], number, slick.worldQuery
function world:project(item, x, y, filter, query)
    query = query or worldQuery.new(self)
    local e = self:get(item)

    query:perform(e, x, y, filter or defaultWorldFilterQueryFunc)

    return query.results, #query.results, query
end

local _cachedQueryRectangle = rectangle.new()

--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param filter slick.worldShapeFilterQueryFunc?
--- @param query slick.worldQuery?
--- @return slick.worldQueryResponse[], number, slick.worldQuery
function world:queryRectangle(x, y, w, h, filter, query)
    query = query or worldQuery.new(self)

    _cachedQueryRectangle:init(x, y, x + w, y + h)
    query:performPrimitive(_cachedQueryRectangle, filter or defaultWorldShapeFilterQueryFunc)

    return query.results, #query.results, query
end

local _cachedQuerySegment = segment.new()

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @param filter slick.worldShapeFilterQueryFunc?
--- @param query slick.worldQuery?
--- @return slick.worldQueryResponse[], number, slick.worldQuery
function world:querySegment(x1, y1, x2, y2, filter, query)
    query = query or worldQuery.new(self)

    _cachedQuerySegment.a:init(x1, y1)
    _cachedQuerySegment.b:init(x2, y2)
    query:performPrimitive(_cachedQuerySegment, filter or defaultWorldShapeFilterQueryFunc)

    return query.results, #query.results, query
end

local _cachedQueryRay = ray.new()

--- @param originX number
--- @param originY number
--- @param directionX number
--- @param directionY number
--- @param filter slick.worldShapeFilterQueryFunc?
--- @param query slick.worldQuery?
--- @return slick.worldQueryResponse[], number, slick.worldQuery
function world:queryRay(originX, originY, directionX, directionY, filter, query)
    query = query or worldQuery.new(self)

    _cachedQueryRay.origin:init(originX, originY)
    _cachedQueryRay.direction:init(directionX, directionY)
    if _cachedQueryRay.direction:lengthSquared() > 0 then
        _cachedQueryRay.direction:normalize(_cachedQueryRay.direction)
    end

    query:performPrimitive(_cachedQueryRay, filter or defaultWorldShapeFilterQueryFunc)

    return query.results, #query.results, query
end

local _cachedQueryPoint = point.new()

--- @param x number
--- @param y number
--- @param filter slick.worldShapeFilterQueryFunc?
--- @param query slick.worldQuery?
--- @return slick.worldQueryResponse[], number, slick.worldQuery
function world:queryPoint(x, y, filter, query)
    query = query or worldQuery.new(self)

    _cachedQueryPoint:init(x, y)
    query:performPrimitive(_cachedQueryPoint, filter or defaultWorldShapeFilterQueryFunc)

    return query.results, #query.results, query
end

local _cachedVisited = {}

--- @type slick.worldFilterQueryFunc
local _cachedFilterFunc

--- comment
--- @param item any
--- @param other any
--- @param shape slick.collision.shape
--- @param otherShape slick.collision.shape
--- @return string | false
local function _visitFilter(item, other, shape, otherShape)
    if _cachedVisited[otherShape] then
        return false
    end

    return _cachedFilterFunc(item, other, shape, otherShape)
end

--- @param item any
--- @param x number
--- @param y number
--- @param filter slick.worldFilterQueryFunc?
--- @param query slick.worldQuery?
--- @return number, number, slick.worldQueryResponse[], number, slick.worldQuery
function world:check(item, x, y, filter, query)
    query = query or worldQuery.new(self)
    local cachedQuery = self.cachedWorldQuery

    _cachedFilterFunc = filter or defaultWorldFilterQueryFunc
    slicktable.clear(_cachedVisited)

    self:project(item, x, y, _visitFilter, cachedQuery)
    while #cachedQuery.results > 0 do
        local result = cachedQuery.results[1]
        query:push(result)

        _cachedVisited[result.otherShape] = true

        local response = self:getResponse(result.response)
        x, y = response(self, cachedQuery, query.results[#query.results], x, y, _visitFilter)
    end

    return x, y, query.results, #query.results, query
end

function world:move(item, x, y, filter, query)
    local actualX, actualY, _, _, query = self:check(item, x, y, filter, query)
    self:update(item, actualX, actualY)

    return actualX, actualY, query.results, #query.results, query
end

--- @package
--- @param shape slick.collision.shape
function world:_addShape(shape)
    self.quadTree:update(shape, shape.bounds)
end

--- @package
--- @param shape slick.collision.shape
function world:_removeShape(shape)
    if self.quadTree:has(shape) then
        self.quadTree:remove(shape)
    end
end

--- @param name string
--- @param response slick.worldResponseFunc
function world:addResponse(name, response)
    assert(not self.responses[name])

    self.responses[name] = response
end

--- @param name string
function world:removeResponse(name)
    assert(self.responses[name])

    self.responses[name] = nil
end

function world:getResponse(name)
    if not self.responses[name] then
        error(string.format("Unknown collision type: %s", name))
    end

    return self.responses[name]
end

return world
