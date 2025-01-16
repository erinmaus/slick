local quadTree = require "slick.collision.quadTree"
local quadTreeQuery = require "slick.collision.quadTreeQuery"
local point = require "slick.geometry.point"
local rectangle = require "slick.geometry.rectangle"
local segment = require "slick.geometry.segment"
local delaunay = require "slick.geometry.triangulation.delaunay"
local edge = require "slick.geometry.triangulation.edge"
local slicktable = require "slick.util.slicktable"
local pool = require "slick.util.pool"
local slickmath = require "slick.util.slickmath"
local search = require "slick.util.search"

local function _compareNumber(a, b)
    return a - b
end

--- @alias slick.geometry.clipper.clipOperation fun(self: slick.geometry.clipper, a: number, b: number)

--- @alias slick.geometry.clipper.polygonUserdata {
---     userdata: any,
---     polygons: table<slick.geometry.clipper.polygon, number[]>,
---     parent: slick.geometry.clipper.polygon,
--- }

--- @alias slick.geometry.clipper.polygon {
---     points: number[],
---     edges: number[],
---     userdata: any[],
---     triangles: number[][],
---     triangleCount: number,
---     polygons: number[][],
---     polygonCount: number,
---     pointToCombinedPointIndex: table<number, number>,
---     quadTreeOptions: slick.collision.quadTreeOptions,
---     quadTree: slick.collision.quadTree,
---     quadTreeQuery: slick.collision.quadTreeQuery,
--- }

--- @param quadTreeOptions slick.collision.quadTreeOptions?
--- @return slick.geometry.clipper.polygon
local function _newPolygon(quadTreeOptions)
    local quadTree = quadTree.new(quadTreeOptions)
    local quadTreeQuery = quadTreeQuery.new(quadTree)

    return {
        points = {},
        edges = {},
        userdata = {},
        triangles = {},
        triangleCount = 0,
        polygons = {},
        polygonCount = 0,
        pointToCombinedPointIndex = {},
        quadTreeOptions = {
            maxLevels = quadTreeOptions and quadTreeOptions.maxLevels,
            maxData = quadTreeOptions and quadTreeOptions.maxData,
            expand = false
        },
        quadTree = quadTree,
        quadTreeQuery = quadTreeQuery,
    }
end

--- @class slick.geometry.clipper
--- @field private innerPolygonsPool slick.util.pool
--- @field private combinedPoints number[]
--- @field private combinedEdges number[]
--- @field private combinedUserdata slick.geometry.clipper.polygonUserdata[]
--- @field private triangulator slick.geometry.triangulation.delaunay
--- @field private pendingPolygonEdges number[]
--- @field private cachedEdge slick.geometry.triangulation.edge
--- @field private edges slick.geometry.triangulation.edge[]
--- @field private edgesPool slick.util.pool
--- @field private subjectPolygon slick.geometry.clipper.polygon
--- @field private otherPolygon slick.geometry.clipper.polygon
--- @field private resultPolygon slick.geometry.clipper.polygon
--- @field private cachedPoint slick.geometry.point
--- @field private cachedSegment slick.geometry.segment
--- @field private clipCleanupOptions slick.geometry.clipper.clipOptions
--- @field private inputCleanupOptions slick.geometry.clipper.clipOptions?
--- @field private indexToResultIndex table<number, number>
--- @field private resultPoints number[]?
--- @field private resultEdges number[]?
--- @field private resultUserdata any[]?
--- @field private resultIndex number
local clipper = {}
local metatable = { __index = clipper }

--- @param triangulator slick.geometry.triangulation.delaunay?
--- @param quadTreeOptions slick.collision.quadTreeOptions?
--- @return slick.geometry.clipper
function clipper.new(triangulator, quadTreeOptions)
    local self = {
        triangulator = triangulator or delaunay.new(),

        combinedPoints = {},
        combinedEdges = {},
        combinedUserdata = {},
        
        innerPolygonsPool = pool.new(),
        
        pendingPolygonEdges = {},
        
        cachedEdge = edge.new(),
        edges = {},
        edgesPool = pool.new(edge),
        
        subjectPolygon = _newPolygon(quadTreeOptions),
        otherPolygon = _newPolygon(quadTreeOptions),
        resultPolygon = _newPolygon(quadTreeOptions),
        
        cachedPoint = point.new(),
        cachedSegment = segment.new(),
        
        clipCleanupOptions = {},

        indexToResultIndex = {},
        resultIndex = 1
    }

    --- @cast self slick.geometry.clipper
    --- @param intersection slick.geometry.triangulation.intersection
    function self.clipCleanupOptions.intersect(intersection)
        --- @diagnostic disable-next-line: invisible
        self:_intersect(intersection)
    end
    
    function self.clipCleanupOptions.dissolve(dissolve)
        --- @diagnostic disable-next-line: invisible
        self:_dissolve(dissolve)
    end

    return setmetatable(self, metatable)
end

--- @private
--- @param t table<slick.geometry.clipper.polygon, number[]>
--- @param other table<slick.geometry.clipper.polygon, number[]>
--- @param ... table<slick.geometry.clipper.polygon, number[]>
--- @return table<slick.geometry.clipper.polygon, number[]>
function clipper:_mergePolygonSet(t, other, ...)
    if not other then
        return t
    end

    for k, v in pairs(other) do
        if not t[k] then
            t[k] = self.innerPolygonsPool:allocate()
            slicktable.clear(t[k])
        end

        for _, p in ipairs(v) do
            local i = search.lessThan(t[k], p, _compareNumber) + 1
            if t[k][i] ~= p then
                table.insert(t[k], i, p)
            end
        end
    end

    return self:_mergePolygonSet(t, ...)
end

--- @private
--- @param intersection slick.geometry.triangulation.intersection
function clipper:_intersect(intersection)
    local a1, b1 = intersection.a1Userdata, intersection.b1Userdata
    local a2, b2 = intersection.a2Userdata, intersection.b2Userdata

    if self.inputCleanupOptions and self.inputCleanupOptions.intersect then
        intersection.a1Userdata = a1.userdata
        intersection.b1Userdata = b1.userdata

        intersection.a2Userdata = a2.userdata
        intersection.b2Userdata = b2.userdata

        self.inputCleanupOptions.intersect(intersection)

        intersection.a1Userdata, intersection.b1Userdata = a1, b1
        intersection.a2Userdata, intersection.b2Userdata = a2, b2
    end

    local userdata = self.combinedUserdata[intersection.resultIndex]
    if not userdata then
        userdata = { polygons = {} }
        self.combinedUserdata[intersection.resultIndex] = userdata
    else
        slicktable.clear(userdata.polygons)
        userdata.parent = nil
    end

    userdata.userdata = intersection.resultUserdata
    self:_mergePolygonSet(userdata.polygons, a1.polygons, b1.polygons, a2.polygons, b2.polygons)

    intersection.resultUserdata = userdata
end

--- @private
--- @param dissolve slick.geometry.triangulation.dissolve
function clipper:_dissolve(dissolve)
    if self.inputCleanupOptions and self.inputCleanupOptions.dissolve then
        local u = dissolve.userdata
        dissolve.userdata = u.userdata

        self.inputCleanupOptions.dissolve(dissolve)

        dissolve.userdata = u
    end
end

function clipper:reset()
    self.edgesPool:reset()
    self.innerPolygonsPool:reset()

    slicktable.clear(self.subjectPolygon.points)
    slicktable.clear(self.subjectPolygon.edges)
    slicktable.clear(self.subjectPolygon.userdata)

    slicktable.clear(self.otherPolygon.points)
    slicktable.clear(self.otherPolygon.edges)
    slicktable.clear(self.otherPolygon.userdata)
    
    slicktable.clear(self.combinedPoints)
    slicktable.clear(self.combinedEdges)
    
    slicktable.clear(self.edges)
    slicktable.clear(self.pendingPolygonEdges)

    slicktable.clear(self.indexToResultIndex)
    self.resultIndex = 1

    self.inputCleanupOptions = nil

    self.resultPoints = nil
    self.resultEdges = nil
    self.resultUserdata = nil
end

--- @type slick.geometry.triangulation.delaunayTriangulationOptions
local _triangulateOptions = {
    refine = true,
    interior = true,
    exterior = false,
    polygonization = true
}

local _cachedPolygonBounds = rectangle.new()

--- @param points number[]
--- @param edges number[]
--- @param userdata any[]?
--- @param options slick.geometry.clipper.clipOptions?
--- @param polygon slick.geometry.clipper.polygon
function clipper:_addPolygon(points, edges, userdata, options, polygon)
    self.triangulator:clean(points, edges, userdata, options, polygon.points, polygon.edges, polygon.userdata)

    local _, triangleCount, _, polygonCount = self.triangulator:triangulate(polygon.points, polygon.edges, _triangulateOptions, polygon.triangles, polygon.polygons)

    polygon.triangleCount = triangleCount
    polygon.polygonCount = polygonCount or 0

    if #polygon.points > 0 then
        _cachedPolygonBounds:init(polygon.points[1], polygon.points[2])

        for i = 3, #polygon.points, 2 do
            _cachedPolygonBounds:expand(polygon.points[i], polygon.points[i + 1])
        end
    else
        _cachedPolygonBounds:init(0, 0, 0, 0)
    end

    polygon.quadTreeOptions.x = _cachedPolygonBounds:left()
    polygon.quadTreeOptions.y = _cachedPolygonBounds:top()
    polygon.quadTreeOptions.width = _cachedPolygonBounds:width()
    polygon.quadTreeOptions.height = _cachedPolygonBounds:height()

    polygon.quadTree:clear()
    polygon.quadTree:rebuild(polygon.quadTreeOptions)

    for i = 1, polygon.polygonCount do
        local p = polygon.polygons[i]
        
        _cachedPolygonBounds.topLeft:init(math.huge, math.huge)
        _cachedPolygonBounds.bottomRight:init(-math.huge, -math.huge)

        for _, vertex in ipairs(p) do
            local xIndex = (vertex - 1) * 2 + 1
            local yIndex = xIndex + 1

            _cachedPolygonBounds:expand(polygon.points[xIndex], polygon.points[yIndex])
        end

        polygon.quadTree:insert(p, _cachedPolygonBounds)
    end
end

--- @param polygon slick.geometry.clipper.polygon
function clipper:_preparePolygon(polygon)
    local numPoints = #self.combinedPoints / 2
    for i = 1, #polygon.points, 2 do
        local x = polygon.points[i]
        local y = polygon.points[i + 1]

        table.insert(self.combinedPoints, x)
        table.insert(self.combinedPoints, y)
        
        local vertexIndex = (i + 1) / 2
        local combinedIndex = vertexIndex + numPoints
        local userdata = self.combinedUserdata[combinedIndex]
        if not userdata then
            userdata = { polygons = {} }
            self.combinedUserdata[combinedIndex] = userdata
        else
            slicktable.clear(userdata.polygons)
        end

        userdata.parent = polygon
        userdata.polygons[polygon] = self.innerPolygonsPool:allocate()
        slicktable.clear(userdata.polygons[polygon])

        userdata.userdata = polygon.userdata[vertexIndex]

        polygon.pointToCombinedPointIndex[i] = combinedIndex
    end

    for i = 1, polygon.polygonCount do
        local p = polygon.polygons[i]

        for _, vertexIndex in ipairs(p) do
            local combinedIndex = vertexIndex + numPoints
            local userdata = self.combinedUserdata[combinedIndex]

            local polygons = userdata.polygons[polygon]
            local innerPolygonIndex = search.lessThan(polygons, i, _compareNumber) + 1
            if polygons[innerPolygonIndex] ~= i then
                table.insert(polygons, innerPolygonIndex, i)
            end
        end
    end

    for i = 1, #polygon.edges, 2 do
        local a = polygon.edges[i] + numPoints
        local b = polygon.edges[i + 1] + numPoints

        table.insert(self.combinedEdges, a)
        table.insert(self.combinedEdges, b)
    end
end

function clipper:_prepare()
    self:_preparePolygon(self.subjectPolygon)
    self:_preparePolygon(self.otherPolygon)
end

function clipper:_segmentInsidePolygon(s, polygon, vertices)
    local isABIntersection, isABCollinear = false, false
    for i = 1, #vertices do
        local j = slickmath.wrap(i, 1, #vertices)

        local aIndex = (vertices[i] - 1) * 2 + 1
        local bIndex = (vertices[j] - 1) * 2 + 1

        local ax = polygon.points[aIndex]
        local ay = polygon.points[aIndex + 1]
        local bx = polygon.points[bIndex]
        local by = polygon.points[bIndex + 1]

        self.cachedSegment.a:init(ax, ay)
        self.cachedSegment.b:init(bx, by)

        isABCollinear = isABCollinear or slickmath.collinear(self.cachedSegment.a, self.cachedSegment.b, s.a, s.b, self.triangulator.epsilon)

        local intersection, _, _, u, v = slickmath.intersection(self.cachedSegment.a, self.cachedSegment.b, s.a, s.b, self.triangulator.epsilon)
        if intersection and u and v and (u > self.triangulator.epsilon and u + self.triangulator.epsilon < 1) and (v > self.triangulator.epsilon and v + self.triangulator.epsilon < 1) then
            isABIntersection = true
        end
    end

    local isAInside, isACollinear = self:_pointInsidePolygon(s.a, polygon, vertices)
    local isBInside, isBCollinear = self:_pointInsidePolygon(s.b, polygon, vertices)

    local isABInside = (isAInside or isACollinear) and (isBInside or isBCollinear)
    
    return isABIntersection or isABInside, isABCollinear, isAInside, isBInside
end

--- @private
--- @param p slick.geometry.point
--- @param polygon slick.geometry.clipper.polygon
--- @param vertices number[]
--- @return boolean, boolean
function clipper:_pointInsidePolygon(p, polygon, vertices)
    local isCollinear = false

    local px = p.x
    local py = p.y

    local minDistance = math.huge

    local isInside = false
    for i = 1, #vertices do
        local j = slickmath.wrap(i, 1, #vertices)

        local aIndex = (vertices[i] - 1) * 2 + 1
        local bIndex = (vertices[j] - 1) * 2 + 1

        local ax = polygon.points[aIndex]
        local ay = polygon.points[aIndex + 1]
        local bx = polygon.points[bIndex]
        local by = polygon.points[bIndex + 1]

        self.cachedSegment.a:init(ax, ay)
        self.cachedSegment.b:init(bx, by)

        isCollinear = isCollinear or slickmath.collinear(self.cachedSegment.a, self.cachedSegment.b, p, p, self.triangulator.epsilon)
        minDistance = math.min(self.cachedSegment:distance(p), minDistance)

        local z = (bx - ax) * (py - ay) / (by - ay) + ax
        if ((ay > py) ~= (by > py) and px < z) then
            isInside = not isInside
        end
    end

    return isInside and minDistance > self.triangulator.epsilon, isCollinear or minDistance < self.triangulator.epsilon
end


local _cachedInsidePoint = point.new()

--- @private
--- @param x number
--- @param y number
--- @param polygon slick.geometry.clipper.polygon
function clipper:_pointInside(x, y, polygon)
    _cachedInsidePoint:init(x, y)
    polygon.quadTreeQuery:perform(_cachedInsidePoint, self.triangulator.epsilon)

    local isInside, isCollinear
    for _, result in ipairs(polygon.quadTreeQuery.results) do
        --- @cast result number[]
        local i, c = self:_pointInsidePolygon(_cachedInsidePoint, polygon, result)

        isInside = isInside or i
        isCollinear = isCollinear or c
    end

    return isInside, isCollinear
end

local _cachedInsideSegment = segment.new()

--- @private
--- @param ax number
--- @param ay number
--- @param bx number
--- @param by number
--- @param polygon slick.geometry.clipper.polygon
function clipper:_segmentInside(ax, ay, bx, by, polygon)
    _cachedInsideSegment.a:init(ax, ay)
    _cachedInsideSegment.b:init(bx, by)
    polygon.quadTreeQuery:perform(_cachedInsideSegment, self.triangulator.epsilon)

    local intersection, collinear, aInside, bInside = false, false, false, false
    for _, result in ipairs(polygon.quadTreeQuery.results) do
        --- @cast result number[]
        local i, c, a, b = self:_segmentInsidePolygon(_cachedInsideSegment, polygon, result)
        intersection = intersection or i
        collinear = collinear or c
        aInside = aInside or a
        bInside = bInside or b
    end

    return intersection or (aInside and bInside), collinear
end

--- @private
--- @param segment slick.geometry.segment
--- @param side -1 | 0 | 1
--- @param parentPolygon slick.geometry.clipper.polygon
--- @param childPolygons number[]
--- @param ... number[]
function clipper:_hasAnyOnSideImpl(segment, side, parentPolygon, childPolygons, ...)
    if not childPolygons and select("#", ...) == 0 then
        return false
    end

    if childPolygons then
        for _, childPolygonIndex in ipairs(childPolygons) do
            local childPolygon = parentPolygon.polygons[childPolygonIndex]

            for i = 1, #childPolygon do
                local xIndex = (childPolygon[i] - 1) * 2 + 1
                local yIndex = xIndex + 1

                local x, y = parentPolygon.points[xIndex], parentPolygon.points[yIndex]
                self.cachedPoint:init(x, y)
                local otherSide = slickmath.direction(segment.a, segment.b, self.cachedPoint, self.triangulator.epsilon)
                if side == otherSide then
                    return true
                end
            end
        end
    end

    return self:_hasAnyOnSideImpl(segment, side, parentPolygon, ...)
end

--- @private
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @param side -1 | 0 | 1
--- @param parentPolygon slick.geometry.clipper.polygon
--- @param childPolygons number[]
--- @param ... number[]
function clipper:_hasAnyOnSide(x1, y1, x2, y2, side, parentPolygon, childPolygons, ...)
    self.cachedSegment.a:init(x1, y1)
    self.cachedSegment.b:init(x2, y2)

    return self:_hasAnyOnSideImpl(self.cachedSegment, side, parentPolygon, childPolygons, ...)
end

function clipper:_addPendingEdge(a, b)
    self.cachedEdge:init(a, b)
    local found = search.first(self.edges, self.cachedEdge, edge.compare)

    if not found then
        table.insert(self.pendingPolygonEdges, a)
        table.insert(self.pendingPolygonEdges, b)

        local e = self.edgesPool:allocate(a, b)
        table.insert(self.edges, search.lessThan(self.edges, e, edge.compare) + 1, e)
    end
end

function clipper:_popPendingEdge()
    local b = table.remove(self.pendingPolygonEdges)
    local a = table.remove(self.pendingPolygonEdges)

    return a, b
end

function clipper:_addResultEdge(a, b)
    local aResultIndex = self.indexToResultIndex[a]
    if not aResultIndex then
        aResultIndex = self.resultIndex
        self.resultIndex = self.resultIndex + 1

        self.indexToResultIndex[a] = aResultIndex
        
        local j = (a - 1) * 2 + 1
        local k = j + 1
        
        table.insert(self.resultPoints, self.resultPolygon.points[j])
        table.insert(self.resultPoints, self.resultPolygon.points[k])
        
        if self.resultUserdata then
            table.insert(self.resultUserdata, self.combinedUserdata[a].userdata)
        end
    end

    local bResultIndex = self.indexToResultIndex[b]
    if not bResultIndex then
        bResultIndex = self.resultIndex
        self.resultIndex = self.resultIndex + 1

        self.indexToResultIndex[b] = bResultIndex
        
        local j = (b - 1) * 2 + 1
        local k = j + 1
        
        table.insert(self.resultPoints, self.resultPolygon.points[j])
        table.insert(self.resultPoints, self.resultPolygon.points[k])
        
        if self.resultUserdata then
            table.insert(self.resultUserdata, self.combinedUserdata[b].userdata)
        end
    end

    table.insert(self.resultEdges, aResultIndex)
    table.insert(self.resultEdges, bResultIndex)
end

--- @param a number
--- @param b number
function clipper:intersection(a, b)
    local aIndex = (a - 1) * 2 + 1
    local bIndex = (b - 1) * 2 + 1

    --- @type slick.geometry.clipper.polygonUserdata
    local aUserdata = self.resultPolygon.userdata[a]
    --- @type slick.geometry.clipper.polygonUserdata
    local bUserdata = self.resultPolygon.userdata[b]

    local aOtherPolygons = aUserdata.polygons[self.otherPolygon]
    local bOtherPolygons = bUserdata.polygons[self.otherPolygon]

    local ax, ay = self.resultPolygon.points[aIndex], self.resultPolygon.points[aIndex + 1]
    local bx, by = self.resultPolygon.points[bIndex], self.resultPolygon.points[bIndex + 1]

    local abInsideSubject = self:_segmentInside(ax, ay, bx, by, self.subjectPolygon)
    local abInsideOther, abCollinearOther = self:_segmentInside(ax, ay, bx, by, self.otherPolygon)

    local hasAnyCollinearOtherPoints = self:_hasAnyOnSide(ax, ay, bx, by, 0, self.otherPolygon, aOtherPolygons, bOtherPolygons)
    local hasAnyCollinearSubjectPoints = self:_hasAnyOnSide(ax, ay, bx, by, 0, self.otherPolygon, aOtherPolygons, bOtherPolygons)
    
    if (abInsideOther and abInsideSubject) or (not abCollinearOther and ((abInsideOther and hasAnyCollinearSubjectPoints) or (abInsideSubject and hasAnyCollinearOtherPoints))) then
        self:_addResultEdge(a, b)
    end
end

--- @param a number
--- @param b number
function clipper:union(a, b)
    local aIndex = (a - 1) * 2 + 1
    local bIndex = (b - 1) * 2 + 1

    local ax, ay = self.resultPolygon.points[aIndex], self.resultPolygon.points[aIndex + 1]
    local bx, by = self.resultPolygon.points[bIndex], self.resultPolygon.points[bIndex + 1]

    local abInsideSubject, abCollinearSubject = self:_segmentInside(ax, ay, bx, by, self.subjectPolygon)
    local abInsideOther, abCollinearOther = self:_segmentInside(ax, ay, bx, by, self.otherPolygon)
    
    abInsideSubject = abInsideSubject or abCollinearSubject
    abInsideOther = abInsideOther or abCollinearOther

    if (abInsideOther or abInsideSubject) and not (abInsideOther and abInsideSubject) then
        self:_addResultEdge(a, b)
    end
end

--- @param a number
--- @param b number
function clipper:difference(a, b)
    local aIndex = (a - 1) * 2 + 1
    local bIndex = (b - 1) * 2 + 1

    local ax, ay = self.resultPolygon.points[aIndex], self.resultPolygon.points[aIndex + 1]
    local bx, by = self.resultPolygon.points[bIndex], self.resultPolygon.points[bIndex + 1]

    --- @type slick.geometry.clipper.polygonUserdata
    local aUserdata = self.resultPolygon.userdata[a]
    --- @type slick.geometry.clipper.polygonUserdata
    local bUserdata = self.resultPolygon.userdata[b]

    local aOtherPolygons = aUserdata.polygons[self.otherPolygon]
    local bOtherPolygons = bUserdata.polygons[self.otherPolygon]

    local hasAnyCollinearOtherPoints = self:_hasAnyOnSide(ax, ay, bx, by, 0, self.otherPolygon, aOtherPolygons, bOtherPolygons)

    local abInsideSubject = self:_segmentInside(ax, ay, bx, by, self.subjectPolygon)
    local abInsideOther = self:_segmentInside(ax, ay, bx, by, self.otherPolygon)
    
    if abInsideSubject and (not abInsideOther or hasAnyCollinearOtherPoints) then
        self:_addResultEdge(a, b)
    end
end

--- @alias slick.geometry.clipper.clipOptions slick.geometry.triangulation.delaunayCleanupOptions

--- @param operation slick.geometry.clipper.clipOperation
--- @param subjectPoints number[]
--- @param subjectEdges number[]
--- @param otherPoints number[]
--- @param otherEdges number[]
--- @param options slick.geometry.clipper.clipOptions?
--- @param subjectUserdata any[]?
--- @param otherUserdata any[]?
--- @param resultPoints number[]?
--- @param resultEdges number[]?
--- @param resultUserdata number[]?
function clipper:clip(operation, subjectPoints, subjectEdges, otherPoints, otherEdges, options, subjectUserdata, otherUserdata, resultPoints, resultEdges, resultUserdata)
    self:reset()

    self:_addPolygon(subjectPoints, subjectEdges, subjectUserdata, options, self.subjectPolygon)
    self:_addPolygon(otherPoints, otherEdges, otherUserdata, options, self.otherPolygon)

    self:_prepare()

    self.inputCleanupOptions = options
    self.triangulator:clean(self.combinedPoints, self.combinedEdges, self.combinedUserdata, self.clipCleanupOptions, self.resultPolygon.points, self.resultPolygon.edges, self.resultPolygon.userdata)

    resultPoints = resultPoints or {}
    resultEdges = resultEdges or {}
    resultUserdata = (subjectUserdata and otherUserdata) and resultUserdata or {}

    self.resultPoints = resultPoints
    self.resultEdges = resultEdges
    self.resultUserdata = resultUserdata

    slicktable.clear(resultPoints)
    slicktable.clear(resultEdges)
    if resultUserdata then
        slicktable.clear(resultUserdata)
    end

    for i = 1, #self.resultPolygon.edges, 2 do
        local a = self.resultPolygon.edges[i]
        local b = self.resultPolygon.edges[i + 1]

        operation(self, a, b)
    end

    self.resultPoints = nil
    self.resultEdges = nil
    self.resultUserdata = nil

    for i = 1, #self.combinedUserdata do
        -- Don't leak user-provided resources.
        self.combinedUserdata[i].userdata = nil
    end

    return resultPoints, resultEdges, resultUserdata
end

return clipper
