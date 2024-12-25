local cache = require("slick.cache")
local entity = require("slick.entity")
local defaultOptions = require("slick.options")
local quadTree = require("slick.collision.quadTree")
local transform = require("slick.geometry.transform")
local quadTreeQuery = require("slick.collision.quadTreeQuery")
local worldQuery    = require("slick.worldQuery")

--- @alias slick.filterQueryFunc fun(item: any, other: any): string | false

--- @class slick.world
--- @field cache slick.cache
--- @field quadTree slick.collision.quadTree
--- @field private entities slick.entity[]
--- @field private itemToEntity table<any, number>
--- @field private freeList number[]
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

    local self = {
        cache = cache.new(options),
        quadTreeOptions = quadTreeOptions,
        quadTree = quadTree.new(quadTreeOptions),
        entities = {},
        itemToEntity = {},
        freeList = {},
        visited = {}
    }

    self.quadTreeQuery = quadTreeQuery.new(self.quadTree)

    return setmetatable(self, metatable)
end

local _cachedTransform = transform.new()

--- @param item any
--- @return slick.entity
--- @overload fun(item: any, x: number, y: number, shape: slick.collision.shapelike): slick.entity
--- @overload fun(item: any, transform: slick.geometry.transform, shape: slick.collision.shapelike): slick.entity
function world:add(item, a, b, c)
    assert(not self:has(item), "item exists in world")

    local e, i
    if #self.freeList > 0 then
        i = table.remove(self.freeList)
        e = self.entities[i]
    else
        e = entity.new()
        table.insert(self.entities, e)
        i = #self.entities
    end
        
    e:init(item)
    if type(a) == "number" and type(b) == "number" then
        _cachedTransform:setTransform(a, b)
        e:setTransform(_cachedTransform)

        --- @cast c slick.collision.shapelike
        entity:setShapes(c)
    else
        --- @cast a slick.geometry.transform
        entity:setTransform(a)

        --- @cast b slick.collision.shapelike
        entity:setShapes(b)
    end

    self.itemToEntity[item] = i
    return entity
end

function world:get(item)
    return self.entities[self.itemToEntity[item]]
end

function world:has(item)
    return self:get(item) ~= nil
end

--- @param item any
function world:remove(item)
    local entityIndex = self.itemToEntity[item]
    local entity = self.entities[entityIndex]

    entity:detach()
    table.insert(self.freeList, entityIndex)

    return entity
end

function world:project(item, x, y, filter, query)
    -- query = query or worldQuery.new()

    -- local e = self:get(item)

    -- self.quadTreeQuery:perform(_cachedbounds)
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

return world
