local polygonMesh = require("slick.collision.polygonMesh")
local util = require("slick.util")

--- @class slick.collision.shapeGroup
--- @field entity slick.entity
--- @field shapes slick.collision.shapelike[]
local shapeGroup = {}
local metatable = { __index = shapeGroup }

--- @param entity slick.entity
--- @param ... slick.collision.shapelike
--- @return slick.collision.shapeGroup
function shapeGroup.new(entity, ...)
    local result = setmetatable({
        entity = entity,
        shapes = {}
    }, metatable)

    result:_addShapes(...)

    return result
end

--- @private
--- @param shape slick.collision.shapelike?
--- @param ... slick.collision.shapelike
function shapeGroup:_addShapes(shape, ...)
    if not shape then
        return
    end

    if util.is(shape, shapeGroup) then
        --- @cast shape slick.collision.shapeGroup
        self:_addShapes(unpack(shape.shapes))
    else
        table.insert(self.shapes, shape)
    end
end

function shapeGroup:attach()
    local shapes = self.shapes

    local index = 1
    while index < #shapes do
        local shape = shapes[index]
        if util.is(shape, polygonMesh) then
            --- @cast shape slick.collision.polygonMesh
            --- @diagnostic disable-next-line: invisible
            shape:build(self.entity.world.cache.triangulator)

            table.remove(shape, index)
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
