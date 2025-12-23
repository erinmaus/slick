local cache = require("slick.cache")
local polygonMesh = require("slick.collision.polygonMesh")
local enum = require("slick.enum")
local tag = require("slick.tag")
local util = require("slick.util")

--- @class slick.collision.shapeGroup
--- @field tag any
--- @field entity slick.entity | slick.cache
--- @field shapes slick.collision.shape[]
local shapeGroup = {}
local metatable = { __index = shapeGroup }

--- @param entity slick.entity | slick.cache
--- @param tag slick.tag | slick.enum | nil
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
--- @param tagInstance slick.tag | slick.enum | nil
--- @param shapeDefinition slick.collision.shapeDefinition?
--- @param ... slick.collision.shapeDefinition
function shapeGroup:_addShapeDefinitions(tagInstance, shapeDefinition, ...)
    if not shapeDefinition then
        return
    end

    local shape
    if shapeDefinition.type == shapeGroup then
        shape = shapeDefinition.type.new(self.entity, shapeDefinition.tag, unpack(shapeDefinition.arguments, 1, shapeDefinition.n))
    else
        shape = shapeDefinition.type.new(self.entity, unpack(shapeDefinition.arguments, 1, shapeDefinition.n))
    end

    local shapeTag = shapeDefinition.tag or tagInstance
    local tagValue = nil
    if util.is(shapeTag, tag) then
        tagValue = shapeTag and shapeTag.value
    elseif util.is(shapeTag, enum) then
        tagValue = shapeTag
    elseif type(shapeTag) ~= "nil" then
        error("expected tag to be an instance of slick.enum or slick.tag")
    end

    shape.tag = tagValue

    self:_addShapes(shape)
    return self:_addShapeDefinitions(tagInstance, ...)
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
        return self:_addShapes(unpack(shape.shapes))
    else
        table.insert(self.shapes, shape)
        return self:_addShapes(...)
    end
end

function shapeGroup:attach()
    local shapes = self.shapes

    local index = 1
    while index <= #shapes do
        local shape = shapes[index]
        if util.is(shape, polygonMesh) then
            --- @type slick.cache
            local c

            if util.is(self.entity, cache) then
                --- @diagnostic disable-next-line: cast-local-type
                c = self.entity
            else
                c = self.entity.world.cache
            end
            
            --- @diagnostic disable-next-line: cast-type-mismatch
            --- @cast shape slick.collision.polygonMesh
            shape:build(c.triangulator)

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
