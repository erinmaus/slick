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

--- @alias slick.worldFilterQueryFunc fun(item: any, other: any, shape: slick.collision.shape, otherShape: slick.collision.shape): string | false
local function defaultWorldFilterQueryFunc()
    return "slide"
end

--- @alias slick.worldShapeFilterQueryFunc fun(item: any, shape: slick.collision.shape): boolean
local function defaultWorldShapeFilterQueryFunc()
    return true
end

--- @alias slick.worldResponseFunc fun(world: slick.world, query: slick.worldQuery, response: slick.worldQueryResponse, x: number, y: number, goalX: number, goalY: number, filter: slick.worldFilterQueryFunc): number, number, number, number

--- @class slick.world
--- @field cache slick.cache
--- @field quadTree slick.collision.quadTree
--- @field options slick.options
--- @field quadTreeOptions slick.collision.quadTreeOptions
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

    local selfOptions = {
        debug = options.debug == nil and defaultOptions.debug or options.debug,
        epsilon = options.epsilon or defaultOptions.epsilon or slickmath.EPSILON,
        maxBounces = options.maxBounces or defaultOptions.maxBounces,
        minSlideDistance = options.minSlideDistance or defaultOptions.minSlideDistance
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
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc?
--- @param query slick.worldQuery?
--- @return slick.worldQueryResponse[], number, slick.worldQuery
function world:project(item, x, y, goalX, goalY, filter, query)
    query = query or worldQuery.new(self)
    local e = self:get(item)

    query:perform(e, x, y, goalX, goalY, filter or defaultWorldFilterQueryFunc)

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

local function _getFirstFuture(query)
end

--- @param query slick.worldQuery
local function _getFutureCollisionIndex(query, direction)
    if true then
        return 1
    end

    for index, result in ipairs(query.results) do
        local dot = direction:dot(result.normal)
        if dot < 0 then
            return index
        end
    end

    print(">>> no future collisions")
    return 1
    -- local smallestDot = math.huge
    -- local bestIndex

    -- for index, result in ipairs(query.results) do
    --     local dot = direction:dot(result.normal)
    --     print(">>>", index, "dot", dot, "dir", direction.x, direction.y, "nrml", result.normal.x, result.normal.y, "depth", result.depth)
    --     if result.time > 0 and direction:lengthSquared() > 0 and dot <= 0 then
    --         print("!!! match", index)
    --         return index
    --     end

    --     if dot <= 0 then
    --         if (dot == smallestDot and query.results[bestIndex].depth < result.depth) or dot < smallestDot then
    --             smallestDot = dot
    --             bestIndex = index
    --         end
    --     end
    -- end

    --return bestIndex
end

local function _willCollide(query, direction)
    if true then
        return true
    end

    if #query.results == 0 then
        return false
    end

    --return false

    for _, result in ipairs(query.results) do
        local dot = direction:dot(result.normal)
        if result.time > 0 or result.depth > 0 or result.offset:lengthSquared() > 0 or dot < 0 then
            print(">>> yes", dot)
            return true
        end
    end

    return false
end

local _cachedCheckStartPosition = point.new()
local _cachedCheckCurrentPosition = point.new()
local _cachedCheckNextPosition = point.new()
local _cachedCheckGoalPosition = point.new()
local _cachedCheckDirection = point.new()

--- @param item any
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc?
--- @param query slick.worldQuery?
--- @return number, number, slick.worldQueryResponse[], number, slick.worldQuery
function world:check(item, goalX, goalY, filter, query)
    query = query or worldQuery.new(self)
    filter = filter or defaultWorldFilterQueryFunc

    local e = self:get(item)
    local x, y = e.transform.x, e.transform.y
    _cachedCheckStartPosition:init(x, y)
    _cachedCheckCurrentPosition:init(x, y)
    _cachedCheckGoalPosition:init(goalX, goalY)
    _cachedCheckStartPosition:direction(_cachedCheckGoalPosition, _cachedCheckDirection)
    _cachedCheckDirection:normalize(_cachedCheckDirection)

    if x ~= goalX or y ~= goalY then
        print(">>> current", x, y)
        print(">>> goal", goalX, goalY)
        print(">>> difference", goalX - x, goalY - y)
    end

    self:project(item, x, y, goalX, goalY, filter, query)
    if #query.results == 0 then
        print(">>> no hits...", #query.quadTreeQuery.results)
        return goalX, goalY, query.results, #query.results, query
    end

    local targetDistance = _cachedCheckStartPosition:distance(_cachedCheckGoalPosition)
    local currentDistance = 0

    for i = 1, #query.results do
        local shapeIndex = 1
        for j = 2, #query.results[i].otherEntity.shapes.shapes do
            if query.results[i].otherEntity.shapes.shapes[j] == query.results[i].otherShape then
                shapeIndex = j
            end
        end

        print("i", i, "#", #query.results, "time", query.results[i].time, "depth", query.results[i].depth, query.results[i].other.type, shapeIndex)
        print("normal", query.results[i].normal.x, query.results[i].normal.y)
        print("touch", query.results[i].touch.x, query.results[i].touch.y)
    end

    local actualX, actualY
    local bounces = 0
    while bounces < self.options.maxBounces and #query.results > 0 and _willCollide(query, _cachedCheckDirection) do
        bounces = bounces + 1

        local index = _getFutureCollisionIndex(query, _cachedCheckDirection)
        -- local index = _getFutureCollisionIndex(query, _cachedCheckDirection)
        -- if not index then
        --     print(">>> no hits")
        --     break
        -- end
        --local index = 1

        local result = query.results[index]
        local responseName = result.response == true and "slide" or result.response

        for i = 1, #query.results do
            local shapeIndex = 1
            for j = 2, #result.otherEntity.shapes.shapes do
                if result.otherEntity.shapes.shapes[j] == query.results[i].otherShape then
                    shapeIndex = j
                end
            end

            print(i == index and "***" or "i", i, "#", #query.results, "time", query.results[i].time, "depth", query.results[i].depth, query.results[i].other.type, shapeIndex)
            print("normal", query.results[i].normal.x, query.results[i].normal.y)
        end

        print("before", x, y)
        print("goal", goalX, goalY)
        print("offset", result.offset.x, result.offset.y)
        print("touch", result.touch.x, result.touch.y)

        --- @cast responseName string
        local response = self:getResponse(responseName)

        _cachedCheckCurrentPosition:init(x, y)
        if result:notTouchingWillTouch() then
            print("* not touching, touch")

            x, y, goalX, goalY = response(self, query, result, x, y, goalX, goalY, filter)
        elseif result:isTouchingWillPenetrate() then
            print("* is touching, will penetrate")

            x, y, goalX, goalY = response(self, query, result, x, y, goalX, goalY, filter)
        elseif result:isTouchingWillNotPenetrate() then
            print("* is touching, will not will not pentrate")
        end
        print("new xy", x, y, "new goal", goalX, goalY)

        -- elseif result:isTouchingWillNotPenetrate() then
        --     print("* is touching, will NOT penetrate")
            
        --     x = goalX
        --     y = goalY
        -- end
        _cachedCheckNextPosition:init(x, y)
        _cachedCheckGoalPosition:init(goalX, goalY)

        _cachedCheckNextPosition:direction(_cachedCheckGoalPosition, _cachedCheckDirection)
        _cachedCheckDirection:normalize(_cachedCheckDirection)

        
        self:project(item, x, y, goalX, goalY, filter, query)

        if #query.results == 0 then
            actualX = goalX
            actualY = goalY
        else
            actualX = x
            actualY = y
        end

        -- if not _willCollide(query) then
        --     break
        -- end

        -- if #query.results == 0 or bounces >= self.options.maxBounces then
        --     goalX = x
        --     goalY = y
        -- end

        print("distance", targetDistance, "curr", currentDistance, "diff", targetDistance - currentDistance)
        print("#", #query.results)
    end

    if bounces > 0 then
        print("bounced", bounces, "times")
        print(">>> xy", goalX, goalY)
        print()
    end

    return actualX, actualY, query.results, #query.results, query

    -- local distance = _cachedCheckStartPosition:distance(_cachedCheckGoalPosition)
    -- local distanceToGoal = distance
    -- local bounces = 0
    -- local above = false
    -- while distance > 0 and distanceToGoal > 0 and #query.results > 0 do
    --     local index = 1
    --     local result = cachedQuery.results[index]
    --     query:push(result)

    --     if result.time > 0 then
    --         above = true
    --         print(">>> index", index, "time", result.time, "depth", result.depth, "distance", result.distance)
    --         print(">>> distance begin", distance, index)
    --     end

    --     local response = self:getResponse(result.response)

    --     do
    --         _cachedCheckCurrentPosition:init(nextX, nextY)

    --         print(">>> time", result.time, ">>> depth", result.depth)

    --         nextX = x + result.offset.x
    --         nextY = y + result.offset.y

    --         _cachedCheckNextPosition:init(nextX, nextY)
    --     end

    --     distance = distance - _cachedCheckNextPosition:distance(_cachedCheckCurrentPosition)

    --     if result.time < self.options.epsilon and result.depth < self.options.epsilon then
    --         print(">>> visited", result.otherShape)
    --         _cachedVisited[result.otherShape] = true
    --     end

    --     if result.time > 0 then
    --         print(">>> distance after", distance)
    --     end
        
    --     goalX, goalY = response(self, cachedQuery, query.results[#query.results], x, y, goalX, goalY, _visitFilter)
    --     x, y = nextX, nextY

    --     _cachedCheckCurrentPosition:init(nextX, nextY)
    --     _cachedCheckGoalPosition:init(goalX, goalY)

    --     distanceToGoal = _cachedCheckCurrentPosition:distance(_cachedCheckGoalPosition)
    --     print(">>> distance", distanceToGoal)
    --     print(">>> goal", goalX, goalY)

    --     slicktable.clear(_cachedVisited)
    --     bounces = bounces + 1

    --     if not _willCollide(query) then
    --         break
    --     end
    -- end

    -- if bounces >= 1 and above then
    --     print(">>> bounces", bounces)
    -- end

    -- return goalX, goalY, query.results, #query.results, query
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

return world
