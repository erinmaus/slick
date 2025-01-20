local polygonMesh = require("slick.collision.polygonMesh")
local util = require("slick.util")

--- @class slick.collision.shapeGroup
--- @field tag any
--- @field entity slick.entity
--- @field shapes slick.collision.shape[]
local shapeGroup = {}
local metatable = { __index = shapeGroup }

--- @param entity slick.entity
--- @param tag slick.tag?
--- @param ... slick.collision.shapeDefinition
--- @return slick.collision.shapeGroup
function shapeGroup.new(entity, tag, ...)
    local result = setmetatable({
        entity = entity,
        shapes = {}
    }, metatable)

    result:_addShapeDefinitions(tag, ...)

    return result
end

--- @private
--- @param tag slick.tag?
--- @param shapeDefinition slick.collision.shapeDefinition?
--- @param ... slick.collision.shapeDefinition
function shapeGroup:_addShapeDefinitions(tag, shapeDefinition, ...)
    if not shapeDefinition then
        return
    end

    local shape
    if shapeDefinition.type == shapeGroup then
        shape = shapeDefinition.type.new(self.entity, shapeDefinition.tag, unpack(shapeDefinition.arguments, 1, shapeDefinition.n))
    else
        shape = shapeDefinition.type.new(self.entity, unpack(shapeDefinition.arguments, 1, shapeDefinition.n))
    end

    local shapeTag = shapeDefinition.tag or tag
    local tagValue = shapeTag and shapeTag.value
    shape.tag = tagValue

    self:_addShapes(shape)
    self:_addShapeDefinitions(tag, ...)
end

--- @private
--- @param shape slick.collision.shapelike
---@param ... slick.collision.shapelike
function shapeGroup:_addShapes(shape, ...)
    if not shape then
        return
    end

    if util.is(shape, shapeGroup) then
        --- @cast shape slick.collision.shapeGroup
        self:_addShapes(unpack(shape.shapes))
    else
        table.insert(self.shapes, shape)
        self:_addShapes(...)
    end
end

function shapeGroup:attach()
    local shapes = self.shapes

    local index = 1
    while index <= #shapes do
        local shape = shapes[index]
        if util.is(shape, polygonMesh) then
            --- @diagnostic disable-next-line: cast-type-mismatch
            --- @cast shape slick.collision.polygonMesh
            shape:build(self.entity.world.cache.triangulator)

            table.remove(shapes, index)
            for i = #shape.polygons, 1, -1 do
                local polygon = shape.polygons[i]
                table.insert(shapes, index, polygon)
            end
        else
            index = index + 1
        end
    end
end

return shapeGroup
