local box = require("slick.collision.box")
local circle = require("slick.collision.circle")
local lineSegment = require("slick.collision.lineSegment")
local polygon = require("slick.collision.polygon")
local polygonMesh = require("slick.collision.polygonMesh")
local shapeGroup = require("slick.collision.shapeGroup")

--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @return slick.collision.shapeDefinition
local function newBox(x, y, w, h)
    return {
        type = box,
        n = 4,
        arguments = { x, y, w, h }
    }
end

--- @param x number
--- @param y number
--- @param radius number
--- @return slick.collision.shapeDefinition
local function newCircle(x, y, radius)
    return {
        type = circle,
        n = 3,
        arguments = { x, y, radius }
    }
end

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return slick.collision.shapeDefinition
local function newLineSegment(x1, y1, x2, y2)
    return {
        type = lineSegment,
        n = 4,
        arguments = { x1, y1, x2, y2 }
    }
end

--- @param vertices number[] a list of x, y coordinates in the form `{ x1, y1, x2, y2, ..., xn, yn }`
--- @return slick.collision.shapeDefinition
local function newPolygon(vertices)
    return {
        type = polygon,
        n = #vertices,
        arguments = { unpack(vertices) }
    }
end

local function _newPolylineHelper(lines, i, j)
    i = i or 1
    j = j or #lines

    if i == j then
        return newLineSegment(unpack(lines[i]))
    else
        return newLineSegment(unpack(lines[i])), _newPolylineHelper(lines, i + 1, j)
    end
end

--- @param lines number[][] an array of segments in the form { { x1, y1, x2, y2 }, { x1, y1, x2, y2 }, ... }
--- @return slick.collision.shapeDefinition
local function newPolyline(lines)
    return {
        type = shapeGroup,
        n = #lines,
        arguments = { _newPolylineHelper(lines) }
    }
end

--- @param ... number[] a list of x, y coordinates in the form `{ x1, y1, x2, y2, ..., xn, yn }`
--- @return slick.collision.shapeDefinition
local function newPolygonMesh(...)
    return {
        type = polygonMesh,
        n = select("#", ...),
        arguments = { ... }
    }
end

--- @alias slick.collision.shapeDefinition {
---     type: { new: fun(entity: slick.entity, ...: any): slick.collision.shapelike },
---     n: number,
---     arguments: table,
--- }

--- @param ... slick.collision.shapeDefinition
--- @return slick.collision.shapeDefinition
local function newShapeGroup(...)
    return {
        type = shapeGroup,
        n = select("#", ...),
        arguments = { ... }
    }
end

return {
    newBox = newBox,
    newCircle = newCircle,
    newLineSegment = newLineSegment,
    newPolygon = newPolygon,
    newPolyline = newPolyline,
    newPolygonMesh = newPolygonMesh,
    newShapeGroup = newShapeGroup,
}
