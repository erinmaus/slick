local shapeGroup = require("slick.collision.shapeGroup")
local rectangle = require("slick.geometry.rectangle")
local transform = require("slick.geometry.transform")

--- @class slick.entity
--- @field item any?
--- @field world slick.world?
--- @field bounds slick.geometry.rectangle
--- @field shapes slick.collision.shapeGroup
--- @field transform slick.geometry.transform
local entity = {}
local metatable = { __index = entity }

--- @return slick.entity
function entity.new()
    local result = setmetatable({ transform = transform.new(), bounds = rectangle.new() }, metatable)
    result.shapes = shapeGroup.new(result)

    return result
end

function entity:init(item)
    self.item = item
    self.shapes = shapeGroup.new(self)
    self.bounds:init(0, 0, 0, 0)

    transform.IDENTITY:copy(self.transform)
end

function entity:_updateBounds()
    local shapes = self.shapes.shapes
    if #shapes == 0 then
        self.bounds:init(0, 0, 0, 0)
        return
    end

    self.bounds:init(shapes[1].bounds:left(), shapes[1].bounds:top(), shapes[1].bounds:right(), shapes[1].bounds:bottom())
    for i = 2, #self.shapes.shapes do
        self.bounds:expand(shapes[i].bounds:left(), shapes[i].bounds:top())
        self.bounds:expand(shapes[i].bounds:right(), shapes[i].bounds:bottom())
    end
end

--- @private
function entity:_updateQuadTree()
    if not self.world then
        return
    end

    local shapes = self.shapes.shapes
    for _, shape in ipairs(shapes) do
        shape:transform(self.transform)
    end
    self:_updateBounds()

    for _, shape in ipairs(self.shapes.shapes) do
        --- @cast shape slick.collision.shape
        --- @diagnostic disable-next-line: invisible
        self.world:_addShape(shape)
    end
end

--- @param ... slick.collision.shapeDefinition
function entity:setShapes(...)
    if self.world then
        for _, shape in ipairs(self.shapes.shapes) do
            --- @cast shape slick.collision.shape
            --- @diagnostic disable-next-line: invisible
            self.world:_removeShape(shape)
        end
    end

    self.shapes = shapeGroup.new(self, nil, ...)
    if self.world then
        self.shapes:attach()
        self:_updateQuadTree()
    end
end

--- @param transform slick.geometry.transform
function entity:setTransform(transform)
    transform:copy(self.transform)
    self:_updateQuadTree()
end

--- @param world slick.world
function entity:add(world)
    self.world = world
    self.shapes:attach()
    self:_updateQuadTree()
end

function entity:detach()
    if self.world then
        for _, shape in ipairs(self.shapes.shapes) do
            --- @cast shape slick.collision.shape
            --- @diagnostic disable-next-line: invisible
            self.world:_removeShape(shape)
        end
    end

    self.item = nil
end

return entity
