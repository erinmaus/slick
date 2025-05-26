local box = require("slick.collision.box")
local lineSegment = require("slick.collision.lineSegment")
local polygon = require("slick.collision.polygon")
local polygonMesh = require("slick.collision.polygonMesh")
local shapeGroup = require("slick.collision.shapeGroup")
local tag = require("slick.tag")
local enum = require("slick.enum")
local util = require("slick.util")

--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param tag slick.tag | slick.enum | nil
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
--- @param segments number?
--- @param tag slick.tag | slick.enum | nil
--- @return slick.collision.shapeDefinition
local function newCircle(x, y, radius, segments, tag)
	local points = segments or math.max(math.floor(math.sqrt(radius * 20)), 8)
    local vertices = {}
    local angleStep = (2 * math.pi) / points

    for angle = 0, 2 * math.pi - angleStep, angleStep do
        table.insert(vertices, x + radius * math.cos(angle))
        table.insert(vertices, y + radius * math.sin(angle))
    end

    return {
        type = polygon,
        n = #vertices,
        tag = tag,
        arguments = vertices
    }
end

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @param tag slick.tag | slick.enum | nil
--- @return slick.collision.shapeDefinition
local function newLineSegment(x1, y1, x2, y2, tag)
    return {
        type = lineSegment,
        n = 4,
        tag = tag,
        arguments = { x1, y1, x2, y2 }
    }
end

local function _newChainHelper(points, i, j)
    local length = #points / 2

    i = i or 1
    j = j or length

    local k = (i % length) + 1
    local x1, y1 = points[(i - 1) * 2 + 1], points[(i - 1) * 2 + 2]
    local x2, y2 = points[(k - 1) * 2 + 1], points[(k - 1) * 2 + 2]
    if i == j then
        return newLineSegment(x1, y1, x2, y2)
    else
        return newLineSegment(x1, y1, x2, y2), _newChainHelper(points, i + 1, j)
    end
end

--- @param points number[] an array of points in the form { x1, y2, x2, y2, ... }
--- @param tag slick.tag | slick.enum | nil
--- @return slick.collision.shapeDefinition
local function newChain(points, tag)
    assert(#points % 2 == 0, "expected a list of (x, y) tuples")
    assert(#points >= 6, "expected a minimum of 3 points")

    return {
        type = shapeGroup,
        n = #points / 2,
        tag = tag,
        arguments = { _newChainHelper(points) }
    }
end

local function _newPolylineHelper(segments, i, j)
    i = i or 1
    j = j or #segments

    if i == j then
        return newLineSegment(unpack(segments[i]))
    else
        return newLineSegment(unpack(segments[i])), _newPolylineHelper(segments, i + 1, j)
    end
end

--- @param segments number[][] an array of segments in the form { { x1, y1, x2, y2 }, { x1, y1, x2, y2 }, ... }
--- @param tag slick.tag | slick.enum | nil
--- @return slick.collision.shapeDefinition
local function newPolyline(segments, tag)
    return {
        type = shapeGroup,
        n = #segments,
        tag = tag,
        arguments = { _newPolylineHelper(segments) }
    }
end

--- @param vertices number[] a list of x, y coordinates in the form `{ x1, y1, x2, y2, ..., xn, yn }`
--- @param tag slick.tag | slick.enum | nil
--- @return slick.collision.shapeDefinition
local function newPolygon(vertices, tag)
    return {
        type = polygon,
        n = #vertices,
        tag = tag,
        arguments = { unpack(vertices) }
    }
end

--- @param ... any
--- @return number, slick.tag?
local function _getTagAndCount(...)
    local n = select("#", ...)

    local maybeTag = select(select("#", ...), ...)
    if util.is(maybeTag, tag) or util.is(maybeTag, enum) then
        return n - 1, maybeTag
    end

    return n, nil
end

--- @param ... number[] | slick.tag | slick.enum a list of x, y coordinates in the form `{ x1, y1, x2, y2, ..., xn, yn }`
--- @return slick.collision.shapeDefinition
local function newPolygonMesh(...)
    local n, tag = _getTagAndCount(...)

    return {
        type = polygonMesh,
        n = n,
        tag = tag,
        arguments = { ... }
    }
end

local function _newMeshHelper(polygons, i, j)
    i = i or 1
    j = j or #polygons

    if i == j then
        return newPolygon(polygons[i])
    else
        return newPolygon(polygons[i]), _newMeshHelper(polygons, i + 1, j)
    end
end

--- @param polygons number[][] an array of segments in the form { { x1, y1, x2, y2, x3, y3, ..., xn, yn }, ... }
--- @param tag slick.tag | slick.enum | nil
--- @return slick.collision.shapeDefinition
local function newMesh(polygons, tag)
    return {
        type = shapeGroup,
        n = #polygons,
        tag = tag,
        arguments = { _newMeshHelper(polygons) }
    }
end

--- @alias slick.collision.shapeDefinition {
---     type: { new: fun(entity: slick.entity | slick.cache, ...: any): slick.collision.shapelike },
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
    newChain = newChain,
    newPolyline = newPolyline,
    newPolygon = newPolygon,
    newPolygonMesh = newPolygonMesh,
    newMesh = newMesh,
    newShapeGroup = newShapeGroup,
}
