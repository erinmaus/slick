local clipper = require "slick.geometry.clipper"
local delaunay = require "slick.geometry.triangulation.delaunay"
local util = require "slick.util"
local slickmath = require "slick.util.slickmath"

local simple = {}

--- @param contours number[][]
--- @return number[], number[]
local function _getPointEdges(contours)
    local points = {}
    local edges = {}

    for _, contour in ipairs(contours) do
        local numPoints = #points
        for j = 1, #contour, 2 do
            table.insert(points, contour[j])
            table.insert(points, contour[j + 1])

            table.insert(edges, (numPoints / 2) + (j + 1) / 2)
            table.insert(edges, (numPoints / 2) + (slickmath.wrap(j, 2, #contour) + 1) / 2)
        end
    end

    return points, edges
end

--- @param points number[]
--- @param polygons number[][]?
--- @return number[][]
local function _getPolygons(points, polygons)
    local result = {}

    if not polygons then
        return result
    end

    for _, polygon in ipairs(polygons) do
        local resultPolygon = {}
        for _, vertex in ipairs(polygon) do
            local i = (vertex - 1) * 2 + 1

            table.insert(resultPolygon, points[i])
            table.insert(resultPolygon, points[i + 1])
        end
        table.insert(result, resultPolygon)
    end

    return result
end

local triangulateOptions = {
    refine = true,
    interior = true,
    exterior = false,
    polygonization = false
}

--- @param contours number[][]
--- @return number[][]
function simple.triangulate(contours)
    local points, edges = _getPointEdges(contours)

    local triangulator = delaunay.new()
    local cleanPoints, cleanEdges = triangulator:clean(points, edges)
    local triangles = triangulator:triangulate(cleanPoints, cleanEdges, triangulateOptions)

    return _getPolygons(cleanPoints, triangles)
end

local polygonizeOptions = {
    refine = true,
    interior = true,
    exterior = false,
    polygonization = true,
    maxPolygonVertexCount = math.huge
}

--- @overload fun(n: number, contours: number[][]): number[][]
--- @overload fun(contours: number[][]): number[][]
--- @return number[][]
function simple.polygonize(n, b)
    local points, edges
    if type(n) == "number" then
        polygonizeOptions.maxPolygonVertexCount = math.max(n, 3)
        points, edges = _getPointEdges(b)
    else
        polygonizeOptions.maxPolygonVertexCount = math.huge
        points, edges = _getPointEdges(n)
    end

    local triangulator = delaunay.new()
    local cleanPoints, cleanEdges = triangulator:clean(points, edges)
    local _, _, polygons = triangulator:triangulate(cleanPoints, cleanEdges, polygonizeOptions)

    return _getPolygons(cleanPoints, polygons)
end

--- @class slick.simple.clipOperation
--- @field operation slick.geometry.clipper.clipOperation
--- @field subject number[][] | slick.simple.clipOperation
--- @field other number[][] | slick.simple.clipOperation
local clipOperation = {}
local clipOperationMetatable = { __index = clipOperation }

--- @package
--- @param clipper slick.geometry.clipper
function clipOperation:perform(clipper)
    local subjectPoints, subjectEdges
    if util.is(self.subject, clipOperation) then
        subjectPoints, subjectEdges = self.subject:perform(clipper)
    else
        subjectPoints, subjectEdges = _getPointEdges(self.subject)
    end

    local otherPoints, otherEdges
    if util.is(self.other, clipOperation) then
        otherPoints, otherEdges = self.other:perform(clipper)
    else
        otherPoints, otherEdges = _getPointEdges(self.other)
    end

    return clipper:clip(self.operation, subjectPoints, subjectEdges, otherPoints, otherEdges)
end

--- @param subject number[][] | slick.simple.clipOperation
--- @param other number[][] | slick.simple.clipOperation
--- @return slick.simple.clipOperation
function simple.newUnionClipOperation(subject, other)
    return setmetatable({
        operation = clipper.union,
        subject = subject,
        other = other
    }, clipOperationMetatable)
end

--- @param subject number[][] | slick.simple.clipOperation
--- @param other number[][] | slick.simple.clipOperation
--- @return slick.simple.clipOperation
function simple.newDifferenceClipOperation(subject, other)
    return setmetatable({
        operation = clipper.difference,
        subject = subject,
        other = other
    }, clipOperationMetatable)
end

--- @param subject number[][] | slick.simple.clipOperation
--- @param other number[][] | slick.simple.clipOperation
--- @return slick.simple.clipOperation
function simple.newIntersectionClipOperation(subject, other)
    return setmetatable({
        operation = clipper.intersection,
        subject = subject,
        other = other
    }, clipOperationMetatable)
end


--- @param operation slick.simple.clipOperation
--- @param maxVertexCount number?
--- @return number[][]
function simple.clip(operation, maxVertexCount)
    maxVertexCount = math.max(maxVertexCount or 3, 3)

    assert(util.is(operation, clipOperation))

    local triangulator = delaunay.new()
    local c = clipper.new(triangulator)

    local clippedPoints, clippedEdges = operation:perform(c)

    local result
    if maxVertexCount == 3 then
        local triangles = triangulator:triangulate(clippedPoints, clippedEdges, triangulateOptions)
        result = triangles
    else
        polygonizeOptions.maxPolygonVertexCount = maxVertexCount
        local _, _, polygons = triangulator:triangulate(clippedPoints, clippedEdges, polygonizeOptions)
        result = polygons
    end

    return _getPolygons(clippedPoints, result)
end

return simple
