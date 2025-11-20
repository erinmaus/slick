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
local slickmath = require("slick.util.slickmath")
local slicktable = require("slick.util.slicktable")

--- @alias slick.worldFilterQueryFunc fun(item: any, other: any, shape: slick.collision.shape, otherShape: slick.collision.shape): string | slick.worldVisitFunc | false
local function defaultWorldFilterQueryFunc()
    return "slide"
end

--- @alias slick.worldShapeFilterQueryFunc fun(item: any, shape: slick.collision.shape): boolean
local function defaultWorldShapeFilterQueryFunc()
    return true
end

--- @alias slick.worldResponseFunc fun(world: slick.world, query: slick.worldQuery, response: slick.worldQueryResponse, x: number, y: number, goalX: number, goalY: number, filter: slick.worldFilterQueryFunc, result: slick.worldQuery): number, number, number, number, string?, slick.worldQueryResponse
--- @alias slick.worldVisitFunc fun(item: any, world: slick.world, query: slick.worldQuery, response: slick.worldQueryResponse, x: number, y: number, goalX: number, goalY: number, projection: boolean): string

--- @class slick.world
--- @field cache slick.cache
--- @field quadTree slick.collision.quadTree
--- @field options slick.options
--- @field quadTreeOptions slick.collision.quadTreeOptions
--- @field private responses table<string, slick.worldResponseFunc>
--- @field private entities slick.entity[]
--- @field private itemToEntity table<any, number>
--- @field private freeWorldQueries slick.worldQuery[]
--- @field private freeList number[]
--- @field private cachedQuery slick.worldQuery
--- @field private cachedPushQuery slick.worldQuery
local world = {}
local metatable = { __index = world }

--- @param t slick.collision.quadTreeOptions?
--- @param width number?
--- @param height number?
--- @param options slick.options?
--- @return slick.collision.quadTreeOptions
local function _getQuadTreeOptions(t, width, height, options)
    t = t or {}
    options = options or defaultOptions

    t.width = width or t.width
    t.height = height or t.height
    t.x = options.quadTreeX or t.x or defaultOptions.quadTreeX
    t.y = options.quadTreeY or t.y or defaultOptions.quadTreeY
    t.maxLevels = options.quadTreeMaxLevels or t.maxLevels or defaultOptions.quadTreeMaxLevels
    t.maxData = options.quadTreeMaxData or t.maxData or defaultOptions.quadTreeMaxData
    t.expand = options.quadTreeExpand == nil and (t.expand == nil and defaultOptions.quadTreeExpand or t.expand) or options.quadTreeExpand

    return t
end

--- @param width number
--- @param height number
--- @param options slick.options?
function world.new(width, height, options)
    assert(type(width) == "number" and width > 0, "expected width to be number > 0")
    assert(type(height) == "number" and height > 0, "expected height to be number > 0")

    options = options or defaultOptions

    local quadTreeOptions = _getQuadTreeOptions({}, width, height, options)

    local selfOptions = {
        debug = options.debug == nil and defaultOptions.debug or options.debug,
        epsilon = options.epsilon or defaultOptions.epsilon or slickmath.EPSILON,
        maxBounces = options.maxBounces or defaultOptions.maxBounces,
        maxJitter = options.maxJitter or defaultOptions.maxJitter,
        quadTreeOptimizationMargin = options.quadTreeOptimizationMargin or defaultOptions.quadTreeOptimizationMargin
    }

    local self = setmetatable({
        cache = cache.new(options),
        options = selfOptions,
        quadTreeOptions = quadTreeOptions,
        quadTree = quadTree.new(quadTreeOptions),
        entities = {},
        itemToEntity = {},
        freeList = {},
        visited = {},
        responses = {},
        freeWorldQueries = {}
    }, metatable)

    self.cachedQuery = worldQuery.new(self)
    self.cachedPushQuery = worldQuery.new(self)
    
    self:addResponse("slide", responses.slide)
    self:addResponse("touch", responses.touch)
    self:addResponse("cross", responses.cross)
    self:addResponse("bounce", responses.bounce)

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

    --- @type slick.worldQuery
    local query = table.remove(self.freeWorldQueries) or worldQuery.new(self)
    query:reset()

    return e
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

--- @overload fun(self: slick.world, item: any, x: number, y: number, shape: slick.collision.shapeDefinition): number, number
--- @overload fun(self: slick.world, item: any, transform: slick.geometry.transform, shape: slick.collision.shapeDefinition): number, number
function world:update(item, a, b, c)
    local e = self:get(item)

    local transform, shapes = _getTransformShapes(e, a, b, c)
    if shapes then
        e:setShapes(shapes)
    end
    e:setTransform(transform)

    return transform.x, transform.y
end

--- @overload fun(self: slick.world, item: any, filter: slick.worldFilterQueryFunc, x: number, y: number, shape: slick.collision.shapeDefinition?): number, number
--- @overload fun(self: slick.world, item: any, filter: slick.worldFilterQueryFunc, transform: slick.geometry.transform, shape: slick.collision.shapeDefinition?): number, number
function world:push(item, filter, a, b, c)
    local e = self:get(item)
    local transform, shapes = _getTransformShapes(e, a, b, c)
    self:update(item, transform, shapes)

    local cachedQuery = self.cachedQuery
    local x, y = transform.x, transform.y
    local originalX, originalY = x, y
    
    local visited = self.cachedPushQuery
    visited:reset()

    self:project(item, x, y, x, y, filter, cachedQuery)
    while #cachedQuery.results > 0 do
        --- @type slick.worldQueryResponse
        local result
        for _, r in ipairs(cachedQuery.results) do
            if r.offset:lengthSquared() > 0 then
                result = r
                break
            end
        end

        if not result then
            break
        end

        local count = 0
        for _, visitedResult in ipairs(visited.results) do
            if visitedResult.shape == result.shape and visitedResult.otherShape == result.otherShape then
                count = count + 1
            end
        end

        local pushFactor = 1.1 ^ count
        local offsetX, offsetY = result.offset.x, result.offset.y
        offsetX = offsetX * pushFactor
        offsetY = offsetY * pushFactor

        x = x + offsetX
        y = y + offsetY
        
        visited:push(result)
        self:project(item, x, y, x, y, filter, cachedQuery)
    end

    self:project(item, x, y, originalX, originalY, filter, cachedQuery)
    if #cachedQuery.results >= 1 then
        local result = cachedQuery.results[1]
        x, y = result.touch.x, result.touch.y
    end

    transform:setTransform(x, y)
    e:setTransform(transform)

    return x, y
end

local _cachedRotateBounds = rectangle.new()
local _cachedRotateItems = {}

--- @param item any
--- @param angle number
--- @param rotateFilter slick.worldFilterQueryFunc
--- @param pushFilter slick.worldFilterQueryFunc
function world:rotate(item, angle, rotateFilter, pushFilter, query)
    query = query or worldQuery.new(self)

    local e = self:get(item)
    
    e.transform:copy(_cachedTransform)
    _cachedTransform:setTransform(nil, nil, angle)
    
    _cachedRotateBounds:init(e.bounds:left(), e.bounds:top(), e.bounds:right(), e.bounds:bottom())
    e:setTransform(_cachedTransform)
    _cachedRotateBounds:expand(e.bounds.topLeft.x, e.bounds.topLeft.y)
    _cachedRotateBounds:expand(e.bounds.bottomRight.x, e.bounds.bottomRight.y)
    
    slicktable.clear(_cachedRotateItems)
    _cachedRotateItems[item] = true

    local responses, numResponses = self:queryRectangle(_cachedRotateBounds:left(), _cachedRotateBounds:top(), _cachedRotateBounds:width(), _cachedRotateBounds:height(), rotateFilter, query)
    for _, response in ipairs(responses) do
        if not _cachedRotateItems[response.item] then
            _cachedRotateItems[response.item] = true
            self:push(response.item, pushFilter, response.entity.transform.x, response.entity.transform.y)
        end
    end

    return responses, numResponses, query
end

world.wiggle = world.push

--- @param deltaTime number
function world:frame(deltaTime)
    -- Nothing for now.
end

--- @param item any
function world:remove(item)
    local entityIndex = self.itemToEntity[item]
    local e = self.entities[entityIndex]

    e:detach()
    table.insert(self.freeList, entityIndex)

    self.itemToEntity[item] = nil
end

--- @param item any
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc?
--- @param query slick.worldQuery?
--- @return slick.worldQueryResponse[], number, slick.worldQuery
function world:project(item, x, y, goalX, goalY, filter, query)
    query = query or worldQuery.new(self)
    local e = self:get(item)

    query:performProjection(e, x, y, goalX, goalY, filter or defaultWorldFilterQueryFunc)

    return query.results, #query.results, query
end

--- @param item any
--- @param x number
--- @param y number
--- @param filter slick.worldFilterQueryFunc?
--- @param query slick.worldQuery?
--- @return slick.worldQueryResponse[], number, slick.worldQuery
function world:test(item, x, y, filter, query)
    return self:project(item, x, y, x, y, filter, query)
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

--- @param result slick.worldQueryResponse
--- @param query slick.worldQuery
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @param projection? boolean
--- @return string
function world:respond(result, query, x, y, goalX, goalY, projection)
    --- @type string
    local responseName
    if type(result.response) == "function" or type(result.response) == "table" then
        responseName = result.response(result.item, self, query, result, x, y, goalX, goalY, not not projection)
    elseif type(result.response) == "string" then
        --- @diagnostic disable-next-line: cast-local-type
        responseName = result.response
    else
        responseName = "slide"
    end
    result.response = responseName

    --- @cast responseName string
    return responseName
end

local _cachedRemappedHandlers = {}

--- @param item any
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc?
--- @param query slick.worldQuery?
--- @return number, number, slick.worldQueryResponse[], number, slick.worldQuery
function world:check(item, goalX, goalY, filter, query)
    if query then
        query:reset()
    else
        query = worldQuery.new(self)
    end

    slicktable.clear(_cachedRemappedHandlers)

    
    local cachedQuery = self.cachedQuery
    filter = filter or defaultWorldFilterQueryFunc
    
    local e = self:get(item)
    local x, y = e.transform.x, e.transform.y
    
    self:project(item, x, y, goalX, goalY, filter, cachedQuery)
    if #cachedQuery.results == 0 then
        return goalX, goalY, query.results, #query.results, query
    end

    local previousX, previousY

    local actualX, actualY
    local bounces = 0
    while bounces < self.options.maxBounces and #cachedQuery.results > 0 do
        bounces = bounces + 1

        local result = cachedQuery.results[1]
        local time = result.time

        --- @type slick.collision.shape
        local shape, otherShape
        repeat
            shape = result.shape
            otherShape = result.otherShape

            --- @type string
            local responseName = self:respond(result, query, x, y, goalX, goalY, false)
            responseName = _cachedRemappedHandlers[otherShape] or responseName

            assert(type(responseName) == "string", "expect name of response handler as string")

            local response = self:getResponse(responseName)

            local remappedResponseName, nextResult
            x, y, goalX, goalY, remappedResponseName, nextResult = response(self, cachedQuery, result, x, y, goalX, goalY, filter, query)

            --- @cast otherShape slick.collision.shapelike
            _cachedRemappedHandlers[otherShape] = remappedResponseName

            result = nextResult
        until not result or result.time > time or (shape == result.shape and otherShape == result.otherShape)

        local isStationary = x == goalX and y == goalY
        local didMove = not (x == previousX and y == previousY)

        local isSameCollision = #cachedQuery.results >= 1 and cachedQuery.results[1].shape == shape and cachedQuery.results[1].otherShape == otherShape
        for i = 2, #cachedQuery.results do
            if isSameCollision then
                break
            end

            if cachedQuery.results[i].time > cachedQuery.results[1].time then
                break
            end
            
            if cachedQuery.results[i].shape == shape and cachedQuery.results[i].otherShape == otherShape then
                isSameCollision = true
                break
            end
        end

        local hasNoCollisions = #cachedQuery.results == 0

        if hasNoCollisions or isStationary then
            actualX = goalX
            actualY = goalY
            break
        else
            actualX = x
            actualY = y
        end

        if didMove and not result then
            break
        end

        if not didMove and isSameCollision then
            break
        end

        previousX, previousY = x, y
    end

    return actualX, actualY, query.results, #query.results, query
end

--- @param item any
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc?
--- @param query slick.worldQuery?
--- @return number
--- @return number
--- @return slick.worldQueryResponse[]
--- @return number
--- @return slick.worldQuery
function world:move(item, goalX, goalY, filter, query)
    local actualX, actualY, _, _, query = self:check(item, goalX, goalY, filter, query)
    self:update(item, actualX, actualY)

    return actualX, actualY, query.results, #query.results, query
end

--- @param width number?
--- @param height number?
--- @param options slick.options?
function world:optimize(width, height, options)
    local x1, y1, x2, y2 = self.quadTree:computeExactBounds()

    local realWidth = x2 - x1
    local realHeight = y2 - y1

    width = width or realWidth
    height = height or realHeight
    
    local x = options and options.quadTreeX or x1
    local y = options and options.quadTreeY or y1

    local margin = options and options.quadTreeOptimizationMargin or self.options.quadTreeOptimizationMargin
    self.options.quadTreeOptimizationMargin = margin

    x = x - realWidth * (margin / 2)
    y = y - realHeight * (margin / 2)
    width = width * (1 + margin / 2)
    height = height * (1 + margin / 2)

    self.quadTreeOptions.x = x
    self.quadTreeOptions.y = y
    self.quadTreeOptions.width = width
    self.quadTreeOptions.height = height

    _getQuadTreeOptions(self.quadTreeOptions, width, height, options)
    self.quadTree:rebuild(self.quadTreeOptions)
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

--- @param name string
--- @return slick.worldResponseFunc
function world:getResponse(name)
    if not self.responses[name] then
        error(string.format("Unknown collision type: %s", name))
    end

    return self.responses[name]
end

--- @param name string
--- @return boolean
function world:hasResponse(name)
    return self.responses[name] ~= nil
end

return world
