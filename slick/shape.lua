local box = require("slick.collision.box")
local circle = require("slick.collision.circle")
local lineSegment = require("slick.collision.lineSegment")
local polygon = require("slick.collision.polygon")
local polygonMesh = require("slick.collision.polygonMesh")
local shapeGroup = require("slick.collision.shapeGroup")
local tag = require("slick.tag")
local util = require("slick.util")

--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param tag slick.tag?
--- @return slick.collision.shapeDefinition
local function newRectangle(x, y, w, h, tag)
    return {
        type = box,
        n = 4,
        tag = tag,
        arguments = { x, y, w, h }
    }
end

--- @param x number
--- @param y number
--- @param radius number
--- @param tag slick.tag?
--- @return slick.collision.shapeDefinition
local function newCircle(x, y, radius, tag)
    return {
        type = circle,
        n = 3,
        tag = tag,
        arguments = { x, y, radius }
    }
end

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @param tag slick.tag
--- @return slick.collision.shapeDefinition
local function newLineSegment(x1, y1, x2, y2, tag)
    return {
        type = lineSegment,
        n = 4,
        tag = tag,
        arguments = { x1, y1, x2, y2 }
    }
end

--- @param vertices number[] a list of x, y coordinates in the form `{ x1, y1, x2, y2, ..., xn, yn }`
--- @param tag slick.tag?
--- @return slick.collision.shapeDefinition
local function newPolygon(vertices, tag)
    return {
        type = polygon,
        n = #vertices,
        tag = tag,
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
--- @param tag slick.tag?
--- @return slick.collision.shapeDefinition
local function newPolyline(lines, tag)
    return {
        type = shapeGroup,
        n = #lines,
        tag = tag,
        arguments = { _newPolylineHelper(lines) }
    }
end

--- @param ... any
--- @return number, slick.tag?
local function _getTagAndCount(...)
    local n = select("#", ...)

    local hasTag = false
    local maybeTag = select(select("#", ...), ...)
    if util.is(maybeTag, tag) then
        return n - 1, maybeTag
    end

    return n, nil
end

--- @param ... number[] a list of x, y coordinates in the form `{ x1, y1, x2, y2, ..., xn, yn }`
--- @return slick.collision.shapeDefinition
local function newPolygonMesh(...)
    local n, tag = _getTagAndCount(...)

    return {
        type = polygonMesh,
        n = n,
        tag = t,
        arguments = { ... }
    }
end

--- @alias slick.collision.shapeDefinition {
---     type: { new: fun(entity: slick.entity, ...: any): slick.collision.shapelike },
---     n: number,
---     tag: slick.tag?,
---     arguments: table,
--- }

--- @param ... slick.collision.shapeDefinition | slick.tag
--- @return slick.collision.shapeDefinition
local function newShapeGroup(...)
    local n, tag = _getTagAndCount(...)

    return {
        type = shapeGroup,
        n = n,
        tag = tag,
        arguments = { ... }
    }
end

return {
    newRectangle = newRectangle,
    newCircle = newCircle,
    newLineSegment = newLineSegment,
    newPolygon = newPolygon,
    newPolyline = newPolyline,
    newPolygonMesh = newPolygonMesh,
    newShapeGroup = newShapeGroup,
}
