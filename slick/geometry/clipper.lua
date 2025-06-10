local quadTree = require "slick.collision.quadTree"
local quadTreeQuery = require "slick.collision.quadTreeQuery"
local merge = require "slick.geometry.merge"
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
---     hasEdge: boolean,
---     isExteriorEdge: boolean,
---     isInteriorEdge: boolean,
--- }

--- @alias slick.geometry.clipper.polygon {
---     points: number[],
---     edges: number[],
---     combinedEdges: number[],
---     interior: number[],
---     exterior: number[],
---     userdata: any[],
---     triangles: number[][],
---     triangleCount: number,
---     polygons: number[][],
---     polygonCount: number,
---     pointToCombinedPointIndex: table<number, number>,
---     combinedPointToPointIndex: table<number, number>,
---     quadTreeOptions: slick.collision.quadTreeOptions,
---     quadTree: slick.collision.quadTree,
---     quadTreeQuery: slick.collision.quadTreeQuery,
---     bounds: slick.geometry.rectangle,
--- }

--- @param quadTreeOptions slick.collision.quadTreeOptions?
--- @return slick.geometry.clipper.polygon
local function _newPolygon(quadTreeOptions)
    local quadTree = quadTree.new(quadTreeOptions)
    local quadTreeQuery = quadTreeQuery.new(quadTree)

    return {
        points = {},
        edges = {},
        combinedEdges = {},
        exterior = {},
        interior = {},
        userdata = {},
        triangles = {},
        triangleCount = 0,
        polygons = {},
        polygonCount = 0,
        pointToCombinedPointIndex = {},
        combinedPointToPointIndex = {},
        quadTreeOptions = {
            maxLevels = quadTreeOptions and quadTreeOptions.maxLevels,
            maxData = quadTreeOptions and quadTreeOptions.maxData,
            expand = false
        },
        quadTree = quadTree,
        quadTreeQuery = quadTreeQuery,
        bounds = rectangle.new(),
        prepareCleanupOptions = {}
    }
end

--- @class slick.geometry.clipper
--- @field private innerPolygonsPool slick.util.pool
--- @field private combinedPoints number[]
--- @field private combinedEdges number[]
--- @field private combinedUserdata slick.geometry.clipper.polygonUserdata[]
--- @field private merge slick.geometry.clipper.merge
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
--- @field private resultExteriorEdges number[]?
--- @field private resultInteriorEdges number[]?
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
        merge = merge.new(),
        
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
    userdata.isExteriorEdge = userdata.isExteriorEdge or
                              intersection.a1Userdata.isExteriorEdge or
                              intersection.a2Userdata.isExteriorEdge or
                              intersection.b1Userdata.isExteriorEdge or
                              intersection.b2Userdata.isExteriorEdge
    userdata.isInteriorEdge = userdata.isInteriorEdge or
                              intersection.a1Userdata.isInteriorEdge or
                              intersection.a2Userdata.isInteriorEdge or
                              intersection.b1Userdata.isInteriorEdge or
                              intersection.b2Userdata.isInteriorEdge

    self:_mergePolygonSet(userdata.polygons, a1.polygons, b1.polygons, a2.polygons, b2.polygons)

    intersection.resultUserdata = userdata
end

--- @private
--- @param dissolve slick.geometry.triangulation.dissolve
function clipper:_dissolve(dissolve)
    if self.inputCleanupOptions and self.inputCleanupOptions.dissolve then
        --- @type slick.geometry.clipper.polygonUserdata
        local u = dissolve.userdata

        --- @type slick.geometry.clipper.polygonUserdata
        local o = dissolve.otherUserdata

        dissolve.userdata = u.userdata
        dissolve.otherUserdata = o.userdata

        self.inputCleanupOptions.dissolve(dissolve)

        dissolve.userdata = u
        dissolve.otherUserdata = o

        if dissolve.resultUserdata ~= nil then
            o.userdata = dissolve.resultUserdata
            dissolve.resultUserdata = nil
        end
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

--- @private
--- @param points number[]
--- @param exterior number[]?
--- @param interior number[]?
--- @param userdata any[]?
--- @param polygon slick.geometry.clipper.polygon
function clipper:_addPolygon(points, exterior, interior, userdata, polygon)
    slicktable.clear(polygon.combinedEdges)
    slicktable.clear(polygon.exterior)
    slicktable.clear(polygon.interior)

    if exterior then
        for _, e in ipairs(exterior) do
            table.insert(polygon.exterior, e)
            table.insert(polygon.combinedEdges, e)
        end
    end
    
    if interior then
        for _, e in ipairs(interior) do
            table.insert(polygon.interior, e)
            table.insert(polygon.combinedEdges, e)
        end
    end

    if userdata then
        for _, u in ipairs(userdata) do
            table.insert(polygon.userdata, u)
        end
    end

    self.triangulator:clean(points, polygon.exterior, nil, nil, polygon.points, polygon.edges)
    local _, triangleCount, _, polygonCount = self.triangulator:triangulate(polygon.points, polygon.edges, _triangulateOptions, polygon.triangles, polygon.polygons)

    polygon.triangleCount = triangleCount
    polygon.polygonCount = polygonCount or 0

    if #polygon.points > 0 then
        polygon.bounds:init(polygon.points[1], polygon.points[2])

        for i = 3, #polygon.points, 2 do
            polygon.bounds:expand(polygon.points[i], polygon.points[i + 1])
        end
    else
        polygon.bounds:init(0, 0, 0, 0)
    end

    polygon.quadTreeOptions.x = polygon.bounds:left()
    polygon.quadTreeOptions.y = polygon.bounds:top()
    polygon.quadTreeOptions.width = math.max(polygon.bounds:width(), self.triangulator.epsilon)
    polygon.quadTreeOptions.height = math.max(polygon.bounds:height(), self.triangulator.epsilon)

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

--- @private
--- @param polygon slick.geometry.clipper.polygon
function clipper:_preparePolygon(points, polygon)
    local numPoints = #self.combinedPoints / 2
    for i = 1, #points, 2 do
        local x = points[i]
        local y = points[i + 1]
        
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
        userdata.hasEdge = false
        
        local index = (i - 1) / 2 + 1
        polygon.pointToCombinedPointIndex[index] = combinedIndex
        polygon.combinedPointToPointIndex[combinedIndex] = index
    end

    for i = 1, polygon.polygonCount do
        local p = polygon.polygons[i]

        for _, vertexIndex in ipairs(p) do
            local combinedIndex = vertexIndex + numPoints
            local userdata = self.combinedUserdata[combinedIndex]
            if userdata then
                local polygons = userdata.polygons[polygon]
                local innerPolygonIndex = search.lessThan(polygons, i, _compareNumber) + 1
                if polygons[innerPolygonIndex] ~= i then
                    table.insert(polygons, innerPolygonIndex, i)
                end
            end
        end
    end

    for i = 1, #polygon.exterior, 2 do
        local a = polygon.exterior[i] + numPoints
        local b = polygon.exterior[i + 1] + numPoints

        self.combinedUserdata[a].hasEdge = true
        self.combinedUserdata[a].isExteriorEdge = true
        self.combinedUserdata[b].hasEdge = true
        self.combinedUserdata[b].isExteriorEdge = true

        table.insert(self.combinedEdges, a)
        table.insert(self.combinedEdges, b)
    end

    for i = 1, #polygon.interior, 2 do
        local a = polygon.interior[i] + numPoints
        local b = polygon.interior[i + 1] + numPoints

        self.combinedUserdata[a].hasEdge = true
        self.combinedUserdata[a].isInteriorEdge = true
        self.combinedUserdata[b].hasEdge = true
        self.combinedUserdata[b].isInteriorEdge = true

        table.insert(self.combinedEdges, a)
        table.insert(self.combinedEdges, b)
    end
end

--- @private
--- @param polygon slick.geometry.clipper.polygon
function clipper:_finishPolygon(polygon)
    slicktable.clear(polygon.userdata)
end

--- @private
--- @param operation slick.geometry.clipper.clipOperation
function clipper:_mergePoints(operation)
    for i = 1, #self.resultPolygon.points, 2 do
        local index = (i - 1) / 2 + 1
        local combinedUserdata = self.resultPolygon.userdata[index]

        local x = self.resultPolygon.points[i]
        local y = self.resultPolygon.points[i + 1]

        if not combinedUserdata.hasEdge then
            if operation == self.difference and not self:_pointInside(x, y, self.otherPolygon) then
                self:_addResultEdge(index)
            elseif operation == self.union then
                self:_addResultEdge(index)
            elseif operation == self.intersection and (self:_pointInside(x, y, self.subjectPolygon) and self:_pointInside(x, y, self.otherPolygon)) then
                self:_addResultEdge(index)
            end
        end
    end
end

--- @private
function clipper:_mergeUserdata()
    if not (self.inputCleanupOptions and self.inputCleanupOptions.merge) then
        return
    end

    local n = #self.combinedPoints / 2
    for i = 1, n do
        local combinedUserdata = self.combinedUserdata[i]
        
        if combinedUserdata.parent then
            if combinedUserdata.parent == self.subjectPolygon then
                self.merge:init(
                    "subject",
                    self.subjectPolygon.combinedPointToPointIndex[i],
                    self.subjectPolygon.userdata[self.subjectPolygon.combinedPointToPointIndex[i]],
                    i)
            elseif combinedUserdata.parent == self.otherPolygon then
                self.merge:init(
                    "other",
                    self.otherPolygon.combinedPointToPointIndex[i],
                    self.otherPolygon.userdata[self.otherPolygon.combinedPointToPointIndex[i]],
                    i)
            end

            self.inputCleanupOptions.merge(self.merge)

            if self.merge.resultUserdata ~= nil then
                self.resultUserdata[self.merge.resultIndex] = self.merge.resultUserdata
            end
        end
    end
end
    
--- @private
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

--- @private
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

--- @private
function clipper:_popPendingEdge()
    local b = table.remove(self.pendingPolygonEdges)
    local a = table.remove(self.pendingPolygonEdges)

    return a, b
end

--- @private
--- @param a number?
--- @param b number?
function clipper:_addResultEdge(a, b)
    local aResultIndex = self.indexToResultIndex[a]
    if not aResultIndex and a then
        aResultIndex = self.resultIndex
        self.resultIndex = self.resultIndex + 1

        self.indexToResultIndex[a] = aResultIndex

        local j = (a - 1) * 2 + 1
        local k = j + 1
        
        table.insert(self.resultPoints, self.resultPolygon.points[j])
        table.insert(self.resultPoints, self.resultPolygon.points[k])
        
        if self.resultUserdata then
            self.resultUserdata[aResultIndex] = self.resultPolygon.userdata[a].userdata
        end
    end

    local bResultIndex = self.indexToResultIndex[b]
    if not bResultIndex and b then
        bResultIndex = self.resultIndex
        self.resultIndex = self.resultIndex + 1

        self.indexToResultIndex[b] = bResultIndex
        
        local j = (b - 1) * 2 + 1
        local k = j + 1
        
        table.insert(self.resultPoints, self.resultPolygon.points[j])
        table.insert(self.resultPoints, self.resultPolygon.points[k])
        
        if self.resultUserdata then
            self.resultUserdata[bResultIndex] = self.resultPolygon.userdata[b].userdata
        end
    end

    if a and b then
        table.insert(self.resultEdges, aResultIndex)
        table.insert(self.resultEdges, bResultIndex)

        if self.resultExteriorEdges and (self.resultPolygon.userdata[a].isExteriorEdge or self.resultPolygon.userdata[b].isExteriorEdge) then
            table.insert(self.resultExteriorEdges, aResultIndex)
            table.insert(self.resultExteriorEdges, bResultIndex)
        end

        if self.resultInteriorEdges and (self.resultPolygon.userdata[a].isInteriorEdge or self.resultPolygon.userdata[b].isInteriorEdge) then
            table.insert(self.resultInteriorEdges, aResultIndex)
            table.insert(self.resultInteriorEdges, bResultIndex)
        end
    end
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

--- @alias slick.geometry.clipper.mergeFunction fun(combine: slick.geometry.clipper.merge)
--- @class slick.geometry.clipper.clipOptions : slick.geometry.triangulation.delaunayCleanupOptions
--- @field merge slick.geometry.clipper.mergeFunction?
local clipOptions = {}

--- @param operation slick.geometry.clipper.clipOperation
--- @param subjectPoints number[]
--- @param subjectEdges number[] | number[][]
--- @param otherPoints number[]
--- @param otherEdges number[] | number[][]
--- @param options slick.geometry.clipper.clipOptions?
--- @param subjectUserdata any[]?
--- @param otherUserdata any[]?
--- @param resultPoints number[]?
--- @param resultEdges number[]?
--- @param resultUserdata any[]?
--- @param resultExteriorEdges number[]?
--- @param resultInteriorEdges number[]?
function clipper:clip(operation, subjectPoints, subjectEdges, otherPoints, otherEdges, options, subjectUserdata, otherUserdata, resultPoints, resultEdges, resultUserdata, resultExteriorEdges, resultInteriorEdges)
    self:reset()

    if type(subjectEdges) == "table" and #subjectEdges >= 1 and type(subjectEdges[1]) == "table" then
        --- @cast subjectEdges number[][]
        self:_addPolygon(subjectPoints, subjectEdges[1], subjectEdges[2], subjectUserdata, self.subjectPolygon)
    else
        self:_addPolygon(subjectPoints, subjectEdges, nil, subjectUserdata, self.subjectPolygon)
    end

    if type(otherEdges) == "table" and #otherEdges >= 1 and type(otherEdges[1]) == "table" then
        --- @cast otherEdges number[][]
        self:_addPolygon(otherPoints, otherEdges[1], otherEdges[2], otherUserdata, self.otherPolygon)
    else
        self:_addPolygon(otherPoints, otherEdges, nil, otherUserdata, self.otherPolygon)
    end

    self:_preparePolygon(subjectPoints, self.subjectPolygon)
    self:_preparePolygon(otherPoints, self.otherPolygon)

    self.inputCleanupOptions = options
    self.triangulator:clean(self.combinedPoints, self.combinedEdges, self.combinedUserdata, self.clipCleanupOptions, self.resultPolygon.points, self.resultPolygon.edges, self.resultPolygon.userdata)

    resultPoints = resultPoints or {}
    resultEdges = resultEdges or {}
    resultUserdata = (subjectUserdata and otherUserdata) and resultUserdata or {}

    self.resultPoints = resultPoints
    self.resultEdges = resultEdges
    self.resultUserdata = resultUserdata
    self.resultPoints = resultPoints
    self.resultInteriorEdges = resultInteriorEdges
    self.resultExteriorEdges = resultExteriorEdges

    slicktable.clear(resultPoints)
    slicktable.clear(resultEdges)
    if resultUserdata then
        slicktable.clear(resultUserdata)
    end
    if resultInteriorEdges then
        slicktable.clear(resultInteriorEdges)
    end
    if resultExteriorEdges then
        slicktable.clear(resultExteriorEdges)
    end

    for i = 1, #self.resultPolygon.edges, 2 do
        local a = self.resultPolygon.edges[i]
        local b = self.resultPolygon.edges[i + 1]

        operation(self, a, b)
    end

    self:_mergePoints(operation)
    self:_mergeUserdata()

    self.resultPoints = nil
    self.resultEdges = nil
    self.resultUserdata = nil

    for i = 1, #self.combinedUserdata do
        -- Don't leak user-provided resources.
        self.combinedUserdata[i].userdata = nil
    end

    return resultPoints, resultEdges, resultUserdata, resultExteriorEdges, resultInteriorEdges
end

return clipper
