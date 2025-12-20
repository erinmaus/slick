local point = require("slick.geometry.point")
local segment = require("slick.geometry.segment")
local dissolve = require("slick.geometry.triangulation.dissolve")
local edge = require("slick.geometry.triangulation.edge")
local hull = require("slick.geometry.triangulation.hull")
local intersection = require("slick.geometry.triangulation.intersection")
local delaunaySortedEdge = require("slick.geometry.triangulation.delaunaySortedEdge")
local delaunaySortedPoint = require("slick.geometry.triangulation.delaunaySortedPoint")
local map = require("slick.geometry.triangulation.map")
local sweep = require("slick.geometry.triangulation.sweep")
local pool = require("slick.util.pool")
local search = require("slick.util.search")
local slickmath = require("slick.util.slickmath")
local slicktable = require("slick.util.slicktable")

--- @class slick.geometry.triangulation.delaunayTriangulationOptions
--- @field public refine boolean?
--- @field public interior boolean?
--- @field public exterior boolean?
--- @field public polygonization boolean?
--- @field public maxPolygonVertexCount number?
local defaultTriangulationOptions = {
    refine = true,
    interior = true,
    exterior = false,
    polygonization = true,
    maxPolygonVertexCount = math.huge
}

--- @alias slick.geometry.triangulation.intersectFunction fun(intersection: slick.geometry.triangulation.intersection)
--- @alias slick.geometry.triangulation.dissolveFunction fun(dissolve: slick.geometry.triangulation.dissolve)
--- @alias slick.geometry.triangulation.mapFunction fun(map: slick.geometry.triangulation.map)

--- @class slick.geometry.triangulation.delaunayCleanupOptions
--- @field public intersect slick.geometry.triangulation.intersectFunction?
--- @field public dissolve slick.geometry.triangulation.dissolveFunction?
--- @field public map slick.geometry.triangulation.mapFunction?
local defaultCleanupOptions = {
    intersect = intersection.default,
    dissolve = dissolve.default,
    map = map.default
}

--- @alias slick.geometry.triangulation.delaunayWorkingPolygon { vertices: number[], merged: boolean? }

--- @class slick.geometry.triangulation.delaunay
--- @field epsilon number (read-only)
--- @field debug boolean (read-only)
--- @field private pointsPool slick.util.pool
--- @field private points slick.geometry.point[]
--- @field private pointsToEdges table<number, slick.geometry.triangulation.edge[]>
--- @field private sortedPointsPool slick.util.pool
--- @field private sortedPoints slick.geometry.triangulation.delaunaySortedPoint[]
--- @field private intersection slick.geometry.triangulation.intersection
--- @field private dissolve slick.geometry.triangulation.dissolve
--- @field private map slick.geometry.triangulation.map
--- @field private segmentsPool slick.util.pool
--- @field private edgesPool slick.util.pool
--- @field private sortedEdgesPool slick.util.pool
--- @field private cachedSegment slick.geometry.segment
--- @field private cachedEdge slick.geometry.triangulation.edge
--- @field private activeEdges slick.geometry.triangulation.delaunaySortedEdge[]
--- @field private temporaryEdges slick.geometry.triangulation.edge[]
--- @field private sortedEdges slick.geometry.triangulation.delaunaySortedEdge[]
--- @field private pendingEdges slick.geometry.triangulation.edge[] | number[]
--- @field private edges slick.geometry.triangulation.edge[]
--- @field private sweepPool slick.util.pool
--- @field private sweeps slick.geometry.triangulation.sweep[]
--- @field private hullsPool slick.util.pool
--- @field private hulls slick.geometry.triangulation.hull[]
--- @field private cachedTriangle number[]
--- @field private triangulation { n: number, triangles: number[][], sorted: number[][], unsorted: number[][] }
--- @field private filter { flags: number[], neighbors: number[], constraints: boolean[], current: number[], next: number[] }
--- @field private index { n: number, vertices: number[][], triangles: number[][], stack: number[] }
--- @field private polygonization { n: number, polygons: slick.geometry.triangulation.delaunayWorkingPolygon[], edges: slick.geometry.triangulation.edge[], pending: slick.geometry.triangulation.edge[], edgesToPolygons: slick.geometry.triangulation.delaunayWorkingPolygon[][] }
local delaunay = {}
local metatable = { __index = delaunay }

--- @param triangle number[]
--- @return number
--- @return number
--- @return number
local function _unpackTriangle(triangle)
    return triangle[1], triangle[2], triangle[3]
end

--- @param a number
--- @param b number
--- @param c number
local function _sortTriangle(a, b, c)
    local x, y, z = a, b, c
    if b < c then
      if b < a then
        x = b
        y = c
        z = a
      end
    elseif c < a then
      x = c
      y = a
      z = b
    end

    return x, y, z
end

--- @param value number
local function _greaterThanZero(value)
    return value > 0
end

--- @param value number
local function _lessThanZero(value)
    return value < 0
end

--- @param a number[]
--- @param b number[]
local function _compareTriangle(a, b)
    local ai, aj, ak = _sortTriangle(_unpackTriangle(a))
    local bi, bj, bk = _sortTriangle(_unpackTriangle(b))

    if ai == bi then
        if aj == bj then
            return ak - bk
        else
            return aj - bj
        end
    end

    return ai - bi
end

--- @param a number[]
--- @param b number[]
local function _lessTriangle(a, b)
    return _compareTriangle(a, b) < 0
end

--- @param p slick.geometry.triangulation.delaunaySortedPoint
--- @param id number
local function _compareSortedPointID(p, id)
    return p.id - id
end

--- @param a slick.geometry.triangulation.delaunaySortedPoint
--- @param b slick.geometry.triangulation.delaunaySortedPoint
local function _lessSortedPointID(a, b)
    return _compareSortedPointID(a, b.id) < 0
end

--- @param e slick.geometry.triangulation.delaunaySortedEdge
--- @param x number
--- @return slick.util.search.compareResult
local function _compareSortedEdgeX(e, x)
    return slickmath.sign(e.segment:right() - x)
end

--- @param e slick.geometry.triangulation.delaunaySortedEdge
--- @param p slick.geometry.point
--- @return slick.util.search.compareResult
local function _compareSortedEdgePoint(e, p)
    local left = e.segment:left()
    
    return slickmath.sign(left - p.x)
end

--- @class slick.geometry.triangulation.delaunayOptions
local defaultDelaunayOptions = {
    epsilon = slickmath.EPSILON,
    debug = false
}

--- @param options slick.geometry.triangulation.delaunayOptions?
function delaunay.new(options)
    options = options or defaultDelaunayOptions
    local epsilon = options.epsilon or defaultDelaunayOptions.epsilon
    local debug = options.debug == nil and defaultDelaunayOptions.debug or not not options.debug

    return setmetatable({
        epsilon = epsilon,
        debug = debug,

        pointsPool = pool.new(point),
        points = {},
        pointsToEdges = {},
        
        intersection = intersection.new(),
        dissolve = dissolve.new(),
        map = map.new(),
        
        sortedPointsPool = pool.new(delaunaySortedPoint),
        sortedPoints = {},
        
        segmentsPool = pool.new(segment),
        edgesPool = pool.new(edge),
        sortedEdgesPool = pool.new(delaunaySortedEdge),
        activeEdges = {},
        temporaryEdges = {},
        pendingEdges = {},
        cachedSegment = segment.new(point.new(), point.new()),
        cachedEdge = edge.new(0, 0),
        sortedEdges = {},
        edges = {},

        sweepPool = pool.new(sweep),
        sweeps = {},

        hullsPool = pool.new(hull),
        hulls = {},

        cachedTriangle = { 0, 0, 0 },
        triangulation = { n = 0, triangles = {}, sorted = {}, unsorted = {} },
        filter = { flags = {}, neighbors = {}, constraints = {}, current = {}, next = {} },
        index = { n = 0, vertices = {}, triangles = {}, stack = {} },
        polygonization = { n = 0, polygons = {}, edges = {}, pending = {}, edgesToPolygons = {} }
    }, metatable)
end

--- @private
function delaunay:_debugVerifyPoints()
    local sortedPoints = self.sortedPoints
    for i = 1, #sortedPoints do
        for j = i + 1, #sortedPoints do
            local a = sortedPoints[i]
            local b = sortedPoints[j]

            assert(a.point:distance(b.point) >= self.epsilon)
        end
    end

    local sortedEdges = self.sortedEdges
    local edges = self.edges

    assert(#sortedEdges == #edges)

    for i = 1, #edges do
        local found = false
        for j = 1, #sortedEdges do
            if sortedEdges[j].edge.min == edges[i].min and sortedEdges[j].edge.max == edges[i].max then
                found = true
                break
            end
        end

        assert(found)
    end

    for i = 1, #sortedEdges do
        local found = false
        for j = 1, #edges do
            if sortedEdges[j].edge.min == edges[i].min and sortedEdges[j].edge.max == edges[i].max then
                found = true
                break
            end
        end

        assert(found)
    end

    for i = 2, #edges do
        assert(edge.compare(edges[i - 1], edges[i]) <= 0)
        assert(edge.compare(edges[i], edges[i - 1]) >= 0)
    end
end

--- @private
--- @param dissolve slick.geometry.triangulation.dissolveFunction
--- @return boolean
function delaunay:_dedupePoints(dissolve, userdata)
    local didDedupe = false

    local edges = self.edges
    local points = self.points
    local sortedPoints = self.sortedPoints
    local pendingEdges = self.pendingEdges

    if self.debug then
        self:_debugVerifyEdges()
    end

    slicktable.clear(pendingEdges)

    local index = 1
    while index <= #sortedPoints do
        local sortedPoint = sortedPoints[index]

        local nextIndex = index + 1
        while nextIndex <= #sortedPoints and sortedPoint.point:distance(sortedPoints[nextIndex].point) < self.epsilon do
            didDedupe = true

            local nextPoint = sortedPoints[nextIndex]
            self.dissolve:init(sortedPoint.point, sortedPoint.id, userdata and userdata[sortedPoint.id], nextPoint.id, userdata and userdata[nextPoint.id])
            dissolve(self.dissolve)

            if self.dissolve.resultUserdata ~= nil then
                userdata[sortedPoint.id] = self.dissolve.resultUserdata
            end

            local pointEdges = self.pointsToEdges[nextPoint.id]
            for i = #pointEdges, 1, -1 do
                local e = pointEdges[i]

                if e.a == nextPoint.id or e.b == nextPoint.id then
                    local index = search.lessThanEqual(pendingEdges, e, edge.compare)

                    --- @cast pendingEdges slick.geometry.triangulation.edge[]
                    if not (index > 0 and edge.compare(pendingEdges[index], e) == 0) then
                        table.insert(pendingEdges, index + 1, e)
                    end
                end
            end

            self.sortedPointsPool:deallocate(table.remove(sortedPoints, nextIndex))
        end

        index = nextIndex
    end

    if self.debug then
        self:_debugVerifyEdges()
    end

    for _, e in ipairs(pendingEdges) do
        self.cachedSegment:init(points[e.a], points[e.b])
        local pointA = sortedPoints[search.first(sortedPoints, points[e.a], delaunaySortedPoint.comparePoint)]
        local pointB = sortedPoints[search.first(sortedPoints, points[e.b], delaunaySortedPoint.comparePoint)]

        if pointA and pointB then
            self.cachedEdge:init(e.a, e.b)
            local hasOldEdge = search.first(edges, self.cachedEdge, edge.compare) ~= nil

            self.cachedEdge:init(pointA.id, pointB.id)
            local hasNewEdge = search.first(edges, self.cachedEdge, edge.compare) ~= nil

            self:_dissolveEdge(e.a, e.b)
            if pointA.id ~= pointB.id and hasOldEdge and not hasNewEdge then
                self:_addEdge(pointA.id, pointB.id)
                self:_addSortedEdge(pointA.id, pointB.id)
            end
        end
    end

    if self.debug then
        self:_debugVerifyPoints()
    end

    return didDedupe
end

--- @private
function delaunay:_debugVerifyEdges()
    local edges = self.edges
    local sortedEdges = self.sortedEdges

    for i = 1, #edges do
        local found = false
        for j = 1, #sortedEdges do
            if sortedEdges[j].edge.min == edges[i].min and sortedEdges[j].edge.max == edges[i].max then
                found = true
                break
            end
        end

        assert(found)
    end

    for i = 1, #sortedEdges do
        local found = false
        for j = 1, #edges do
            if sortedEdges[j].edge.min == edges[i].min and sortedEdges[j].edge.max == edges[i].max then
                found = true
                break
            end
        end

        assert(found)
    end

    for i = 2, #edges do
        assert(edge.compare(edges[i - 1], edges[i]) <= 0)
        assert(edge.compare(edges[i], edges[i - 1]) >= 0)
    end
end

--- @private
function delaunay:_debugVerifyDuplicateEdges()
    local edges = self.edges

    for i = 1, #edges do
        for j = i + 1, #edges do
            local a = edges[i]
            local b = edges[j]
            assert(not (a.min == b.min and a.max == b.max))
        end
    end
end

--- @private
--- @return boolean
function delaunay:_dedupeEdges()
    local didDedupe = false
    local edges = self.edges
    
    local index = 1
    while index < #edges - 1 do
        local e = edges[index]
        local n = edges[index + 1]
        
        if e.a == e.b then
            didDedupe = true
            self:_dissolveEdge(e.a, e.b)
        elseif e.min == n.min and e.max == n.max then
            didDedupe = true
            self:_dissolveEdge(e.a, e.b)
        else
            index = index + 1
        end
    end

    if self.debug then
        self:_debugVerifyEdges()
        self:_debugVerifyDuplicateEdges()
    end

    return didDedupe
end

local function _greater(a, b)
    return a > b
end

--- @private
function delaunay:_splitEdgesAgainstPoints(intersect, userdata)
    local points = self.points
    local sortedPoints = self.sortedPoints
    local sortedEdges = self.sortedEdges

    for i = #sortedEdges, 1, -1 do
        local sortedEdge = sortedEdges[i]
        local e = sortedEdge.edge
        local s = sortedEdge.segment

        local start = math.max(search.lessThanEqual(sortedPoints, s.a, delaunaySortedPoint.comparePoint), 1)
        local stop = search.lessThanEqual(sortedPoints, s.b, delaunaySortedPoint.comparePoint, start)

        local dissolve = false
        for j = stop, start, -1 do
            local sortedPoint = sortedPoints[j]
            if e.a ~= sortedPoint.id and e.b ~= sortedPoint.id then
                local intersection, x, y = slickmath.intersection(s.a, s.b, sortedPoint.point, sortedPoint.point)
                if intersection and not (x and y) then
                    self:_addEdge(e.a, sortedPoint.id)
                    self:_addEdge(sortedPoint.id, e.b)

                    self:_addSortedEdge(e.a, sortedPoint.id)
                    self:_addSortedEdge(sortedPoint.id, e.b)

                    self.intersection:init(sortedPoint.id)

                    self.intersection:setLeftEdge(
                        points[e.a], points[sortedPoint.id],
                        e.a, sortedPoint.id,
                        1,
                        userdata and userdata[e.a],
                        userdata and userdata[sortedPoint.id])

                    self.intersection:setRightEdge(
                        points[sortedPoint.id], points[e.b],
                        sortedPoint.id, e.b,
                        1,
                        userdata and userdata[sortedPoint.id],
                        userdata and userdata[e.b])

                    self.intersection.result:init(sortedPoint.point.x, sortedPoint.point.y)

                    intersect(self.intersection)

                    if userdata then
                        if self.intersection.resultUserdata ~= nil then
                            userdata[self.intersection.resultIndex] = self.intersection.resultUserdata
                        end

                        userdata[self.intersection.a1Index] = self.intersection.a1Userdata
                        userdata[self.intersection.b1Index] = self.intersection.b1Userdata
                        userdata[self.intersection.a2Index] = self.intersection.a2Userdata
                        userdata[self.intersection.b2Index] = self.intersection.b2Userdata
                    end

                    dissolve = true
                end
            end
        end

        if dissolve then
            self:_dissolveEdge(e.a, e.b)
        end
    end

    if self.debug then
        self:_debugVerifyEdges()
    end
end

--- @private
--- @param intersect slick.geometry.triangulation.intersectFunction
--- @param userdata any[]?
--- @return boolean
function delaunay:_splitEdgesAgainstEdges(intersect, userdata)
    local isDirty = false

    local points = self.points
    local sortedPoints = self.sortedPoints
    local edges = self.edges
    local sortedEdges = self.sortedEdges
    local temporaryEdges = self.temporaryEdges
    local pendingEdges = self.pendingEdges
    local activeEdges = self.activeEdges

    slicktable.clear(temporaryEdges)
    slicktable.clear(pendingEdges)
    slicktable.clear(activeEdges)

    local rightEdge = sortedEdges[1] and sortedEdges[1].segment:right() or math.huge
    table.insert(activeEdges, sortedEdges[1])

    for i = 2, #sortedEdges do
        local selfEdge = sortedEdges[i]

        local leftEdge = selfEdge.segment:left()

        if leftEdge > rightEdge then
            rightEdge = leftEdge

            local stop = search.lessThan(activeEdges, leftEdge, _compareSortedEdgeX)
            for j = stop, 1, -1 do
                assert(activeEdges[j].segment:right() < leftEdge)
                table.remove(activeEdges, j)
            end
        end
        
        local intersected = false
        for j, otherEdge in ipairs(activeEdges) do
            local overlaps = selfEdge.segment:overlap(otherEdge.segment)
            local connected = (selfEdge.edge.a == otherEdge.edge.a or selfEdge.edge.a == otherEdge.edge.b or selfEdge.edge.b == otherEdge.edge.a or selfEdge.edge.b == otherEdge.edge.b)
            
            if overlaps and not connected then
                local a1 = points[selfEdge.edge.a]
                local b1 = points[selfEdge.edge.b]
                local a2 = points[otherEdge.edge.a]
                local b2 = points[otherEdge.edge.b]
                
                local intersection, x, y, u, v = slickmath.intersection(a1, b1, a2, b2)
                if intersection and x and y and u and v then
                    intersected = true
                    isDirty = true

                    -- Edges intersect.
                    self:_addPoint(x, y)

                    local point = points[#points]
                    local sortedPoint = self:_newSortedPoint(#points)
                    table.insert(sortedPoints, search.lessThan(sortedPoints, sortedPoint, sortedPoint.compare) + 1, sortedPoint)

                    table.insert(temporaryEdges, self:_newEdge(selfEdge.edge.a, sortedPoint.id))
                    table.insert(temporaryEdges, self:_newEdge(sortedPoint.id, selfEdge.edge.b))
                    table.insert(temporaryEdges, self:_newEdge(otherEdge.edge.a, sortedPoint.id))
                    table.insert(temporaryEdges, self:_newEdge(sortedPoint.id, otherEdge.edge.b))

                    self.intersection:init(#points)

                    self.intersection:setLeftEdge(
                        a1, b1,
                        selfEdge.edge.a, selfEdge.edge.b,
                        u,
                        userdata and userdata[selfEdge.edge.a],
                        userdata and userdata[selfEdge.edge.b])
                        
                    self.intersection:setRightEdge(
                        a2, b2,
                        otherEdge.edge.a, otherEdge.edge.b,
                        v,
                        userdata and userdata[otherEdge.edge.a],
                        userdata and userdata[otherEdge.edge.b])

                    self.intersection.result:init(point.x, point.y)

                    intersect(self.intersection)
                    point:init(self.intersection.result.x, self.intersection.result.y)

                    if userdata then
                        if self.intersection.resultUserdata ~= nil then
                            userdata[self.intersection.resultIndex] = self.intersection.resultUserdata
                        end

                        userdata[self.intersection.a1Index] = self.intersection.a1Userdata
                        userdata[self.intersection.b1Index] = self.intersection.b1Userdata
                        userdata[self.intersection.a2Index] = self.intersection.a2Userdata
                        userdata[self.intersection.b2Index] = self.intersection.b2Userdata
                    end

                    table.insert(pendingEdges, search.first(edges, selfEdge.edge, edge.compare))
                    table.insert(pendingEdges, search.first(edges, otherEdge.edge, edge.compare))

                    table.remove(activeEdges, j)

                    break
                end
            end
        end

        if not intersected then
            local index = search.lessThan(activeEdges, selfEdge.segment:right(), _compareSortedEdgeX)
            table.insert(activeEdges, index + 1, selfEdge)
        end
    end

    table.sort(pendingEdges, _greater)
    for i = 1, #pendingEdges do
        local index = pendingEdges[i]
        local previousIndex = i > 1 and pendingEdges[i - 1]

        if index ~= previousIndex and type(index) == "number" then
            local e = edges[index]

            self:_dissolveEdge(e.a, e.b)
        end
    end

    for _, e in ipairs(temporaryEdges) do
        self:_addEdge(e.a, e.b)
        self:_addSortedEdge(e.a, e.b)

        self.edgesPool:deallocate(e)
    end

    if self.debug then
        self:_debugVerifyEdges()
    end

    return isDirty
end

--- @param points number[]
--- @param edges number[]
--- @param userdata any[]?
--- @param options slick.geometry.triangulation.delaunayCleanupOptions?
--- @param outPoints number[]?
--- @param outEdges number[]?
--- @param outUserdata any[]?
function delaunay:clean(points, edges, userdata, options, outPoints, outEdges, outUserdata)
    options = options or defaultCleanupOptions

    local dissolveFunc = options.dissolve == nil and defaultCleanupOptions.dissolve or options.dissolve
    dissolveFunc = dissolveFunc or dissolve.default

    local intersectFunc = options.intersect == nil and defaultCleanupOptions.intersect or options.intersect
    intersectFunc = intersectFunc or intersection.default

    local mapFunc = options.map == nil and defaultCleanupOptions.map or options.map
    mapFunc = mapFunc or map.default

    self:reset()

    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        self:_addPoint(x, y)

        local index = #self.points
        local sortedPoint = self:_newSortedPoint(index)
        table.insert(self.sortedPoints, search.lessThan(self.sortedPoints, sortedPoint, delaunaySortedPoint.compare) + 1, sortedPoint)
    end

    if edges then
        for i = 1, #edges, 2 do
            local e1 = edges[i]
            local e2 = edges[i + 1]

            if e1 ~= e2 then
                self:_addEdge(e1, e2)
                self:_addSortedEdge(e1, e2)
            end
        end
    end

    local continue
    repeat
        continue = false

        self:_dedupePoints(dissolveFunc, userdata)
        self:_dedupeEdges()
        self:_splitEdgesAgainstPoints(intersectFunc, userdata)

        continue = self:_splitEdgesAgainstEdges(intersectFunc, userdata)
    until not continue

    table.sort(self.sortedPoints, _lessSortedPointID)

    outPoints = outPoints or {}
    outEdges = outEdges or {}

    slicktable.clear(outPoints)
    slicktable.clear(outEdges)

    if userdata then
        outUserdata = outUserdata or {}
        slicktable.clear(outUserdata)
    end

    local currentPointIndex = 1
    for i = 1, #self.sortedPoints do
        local sortedPoint = self.sortedPoints[i]
        sortedPoint.newID = currentPointIndex
        currentPointIndex = currentPointIndex + 1

        table.insert(outPoints, sortedPoint.point.x)
        table.insert(outPoints, sortedPoint.point.y)

        if userdata and outUserdata then
            outUserdata[sortedPoint.newID] = userdata[sortedPoint.id]
        end

        if mapFunc then
            self.map:init(sortedPoint.point, sortedPoint.id, sortedPoint.newID)
            mapFunc(self.map)
        end
    end

    for i = 1, #self.edges do
        local e = self.edges[i]

        assert(e.min ~= e.max)

        local a = search.first(self.sortedPoints, e.min, _compareSortedPointID)
        local b = a and search.first(self.sortedPoints, e.max, _compareSortedPointID, a)

        if a and b then
            local pointA = self.sortedPoints[a]
            local pointB = self.sortedPoints[b]

            table.insert(outEdges, pointA.newID)
            table.insert(outEdges, pointB.newID)
        end
    end

    return outPoints, outEdges, outUserdata
end

--- @param points number[]
--- @param edges number[]
--- @param options slick.geometry.triangulation.delaunayTriangulationOptions?
--- @param result number[][]?
--- @param polygons number[][]?
--- @return number[][], number, number[][]?, number?
function delaunay:triangulate(points, edges, options, result, polygons)
    options = options or defaultTriangulationOptions

    local refine = options.refine == nil and defaultTriangulationOptions.refine or options.refine
    local interior = options.interior == nil and defaultTriangulationOptions.interior or options.interior
    local exterior = options.exterior == nil and defaultTriangulationOptions.exterior or options.exterior
    local polygonization = options.polygonization == nil and defaultTriangulationOptions.polygonization or options.polygonization
    local maxPolygonVertexCount = options.maxPolygonVertexCount or defaultTriangulationOptions.maxPolygonVertexCount

    self:reset()

    if #points == 0 then
        return result or {}, 0, polygons or (polygonization and {}) or nil, 0
    end

    if self.debug then
        assert(points and #points >= 6 and #points % 2 == 0,
            "expected three or more points in the form of x1, y1, x2, y2, ..., xn, yn")
        assert(not edges or #edges == 0 or #edges % 2 == 0,
            "expected zero or two or more indices in the form of a1, b1, a2, b2, ... an, bn")
    end

    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        self:_addPoint(x, y)
    end

    if edges then
        for i = 1, #edges, 2 do
            local p1 = edges[i]
            local p2 = edges[i + 1]
            self:_addEdge(p1, p2)
        end
    end

    self:_sweep()
    self:_triangulate()

    if refine or interior or exterior or polygonization then
        self:_buildIndex()

        if refine then
            self:_refine()
        end

        self:_materialize()

        if interior and exterior then
            self:_filter(0)
        elseif interior then
            self:_filter(-1)
        elseif exterior then
            self:_filter(1)
        end
    end

    result = result or {}

    local triangles = self.triangulation.triangles
    for i = 1, #triangles do
        local inputTriangle = triangles[i]
        local outputTriangle = result[i]

        if outputTriangle then
            outputTriangle[1], outputTriangle[2], outputTriangle[3] = _unpackTriangle(inputTriangle)
        else
            outputTriangle = { _unpackTriangle(inputTriangle) }
            table.insert(result, outputTriangle)
        end
    end

    local polygonCount
    if polygonization then
        polygons = polygons or {}

        --- @cast maxPolygonVertexCount number
        polygons, polygonCount = self:_polygonize(maxPolygonVertexCount, polygons)
    end

    return result, #triangles, polygons, polygonCount
end

--- @private
function delaunay:_sweep()
    for i, point in ipairs(self.points) do
        self:_addSweep(sweep.TYPE_POINT, point, i)
    end

    for i, edge in ipairs(self.edges) do
        local a, b = self.points[edge.a], self.points[edge.b]
        if b.x < a.x then
            a, b = b, a
        end

        if a.x ~= b.x then
            self:_addSweep(sweep.TYPE_EDGE_START, self:_newSegment(a, b), i)
            self:_addSweep(sweep.TYPE_EDGE_STOP, self:_newSegment(b, a), i)
        end
    end

    table.sort(self.sweeps, sweep.less)
end

--- @private
function delaunay:_triangulate()
    local minX = self.sweeps[1].point.x
    minX = minX - (1 + math.abs(minX) * 2 ^ -52)
    table.insert(self.hulls, self:_newHull(self:_newPoint(minX, 1), self:_newPoint(minX, 0), 0))

    for _, sweep in ipairs(self.sweeps) do
        if sweep.type == sweep.TYPE_POINT then
            local point = sweep.data

            --- @cast point slick.geometry.point
            self:_addPointToHulls(point, sweep.index)
        elseif sweep.type == sweep.TYPE_EDGE_START then
            self:_splitHulls(sweep)
        elseif sweep.type == sweep.TYPE_EDGE_STOP then
            self:_mergeHulls(sweep)
        else
            if self.debug then
                assert(false, "unhandled sweep event type")
            end
        end
    end
end

--- @private
--- @param i number
--- @param j number
--- @param k number
function delaunay:_addTriangleToIndex(i, j, k)
    table.insert(self.index.vertices[i], j)
    table.insert(self.index.vertices[i], k)

    table.insert(self.index.vertices[j], k)
    table.insert(self.index.vertices[j], i)

    table.insert(self.index.vertices[k], i)
    table.insert(self.index.vertices[k], j)
end

--- @private
--- @param i number
--- @param j number
--- @param k number
function delaunay:_removeTriangleFromIndex(i, j, k)
    self:_removeTriangleVertex(i, j, k)
    self:_removeTriangleVertex(j, k, i)
    self:_removeTriangleVertex(k, i, j)
end

--- @private
--- @param i number
--- @param j number
--- @param k number
function delaunay:_removeTriangleVertex(i, j, k)
    local vertices = self.index.vertices[i]

    for index = 2, #vertices, 2 do
        if vertices[index - 1] == j and vertices[index] == k then
            vertices[index - 1] = vertices[#vertices - 1]
            vertices[index] = vertices[#vertices]

            table.remove(vertices, #vertices)
            table.remove(vertices, #vertices)

            break
        end
    end
end

--- @private
--- @param i number
--- @param j number
--- @return number?
function delaunay:_getOppositeVertex(j, i)
    local vertices = self.index.vertices[i]
    for k = 2, #vertices, 2 do
        if vertices[k] == j then
            return vertices[k - 1]
        end
    end
    
    return nil
end

--- @private
--- @param i number
--- @param j number
function delaunay:_flipTriangle(i, j)
    local a = self:_getOppositeVertex(i, j)
    local b = self:_getOppositeVertex(j, i)

    if self.debug then
        assert(a, "cannot flip triangle (no opposite vertex for IJ)")
        assert(b, "cannot flip triangle (no opposite vertex for JI)")
    end

    --- @cast a number
    --- @cast b number

    self:_removeTriangleFromIndex(i, j, a)
    self:_removeTriangleFromIndex(j, i, b)

    self:_addTriangleToIndex(i, b, a)
    self:_addTriangleToIndex(j, a, b)
end

--- @private
--- @param a number
--- @param b number
--- @param x number
function delaunay:_testFlipTriangle(a, b, x)
    local y = self:_getOppositeVertex(a, b)
    if not y then
        return
    end

    if b < a then
        a, b = b, a
        x, y = y, x
    end

    if self:_isTriangleEdgeConstrained(a, b) then
        return
    end

    local result = slickmath.inside(
        self.points[a],
        self.points[b],
        self.points[x],
        self.points[y])
    if result < 0 then
        table.insert(self.index.stack, a)
        table.insert(self.index.stack, b)
    end
end

--- @private
function delaunay:_buildIndex()
    local vertices = self.index.vertices

    if #vertices < #self.points then
        for _ = #vertices, #self.points do
            table.insert(vertices, {})
        end
    end

    self.index.n = #self.points
    for i = 1, self.index.n do
        slicktable.clear(vertices[i])
    end

    local unsorted = self.triangulation.unsorted
    for i = 1, self.triangulation.n do
        local triangle = unsorted[i]
        self:_addTriangleToIndex(_unpackTriangle(triangle))
    end
end

--- @private
function delaunay:_isTriangleEdgeConstrained(i, j)
    self.cachedEdge:init(i, j)
    return search.first(self.edges, self.cachedEdge, edge.compare) ~= nil
end

--- @private
function delaunay:_refine()
    for i = 1, #self.points do
        local vertices = self.index.vertices[i]
        for j = 2, #vertices, 2 do
            local first = i
            local second = vertices[j]

            if second < first and not self:_isTriangleEdgeConstrained(first, second) then
                local x = vertices[j - 1]
                local y

                for k = 2, #vertices, 2 do
                    if vertices[k - 1] == second then
                        y = vertices[k]
                    end
                end


                if y then
                    local result = slickmath.inside(
                        self.points[first],
                        self.points[second],
                        self.points[x],
                        self.points[y])

                    if result < 0 then
                        table.insert(self.index.stack, first)
                        table.insert(self.index.stack, second)
                    end
                end
            end
        end
    end

    local stack = self.index.stack
    while #stack > 0 do
        local b = table.remove(stack, #stack)
        local a = table.remove(stack, #stack)

        local x, y
        local vertices = self.index.vertices[a]
        for i = 2, #vertices, 2 do
            local s = vertices[i - 1]
            local t = vertices[i]

            if s == b then
                y = t
            elseif t == b then
                x = s
            end
        end

        if x and y then
            local result = slickmath.inside(
                self.points[a],
                self.points[b],
                self.points[x],
                self.points[y])

            if result < 0 then
                self:_flipTriangle(a, b)
                self:_testFlipTriangle(x, a, y)
                self:_testFlipTriangle(a, y, x)
                self:_testFlipTriangle(y, b, x)
                self:_testFlipTriangle(b, x, y)
            end
        end
    end
end

--- @private
function delaunay:_sortTriangulation()
    local sorted = self.triangulation.sorted
    local unsorted = self.triangulation.unsorted

    slicktable.clear(sorted)

    for i = 1, self.triangulation.n do
        table.insert(sorted, unsorted[i])
    end

    table.sort(sorted, _lessTriangle)
end

--- @private
function delaunay:_prepareFilter()
    local flags = self.filter.flags
    local neighbors = self.filter.neighbors
    local constraints = self.filter.constraints

    for _ = 1, self.triangulation.n do
        table.insert(flags, 0)

        table.insert(neighbors, 0)
        table.insert(neighbors, 0)
        table.insert(neighbors, 0)

        table.insert(constraints, false)
        table.insert(constraints, false)
        table.insert(constraints, false)
    end

    local t = self.cachedTriangle
    local sorted = self.triangulation.sorted

    for i = 1, self.triangulation.n do
        local triangle = sorted[i]

        for j = 1, 3 do
            local x = triangle[j]
            local y = triangle[j % 3 + 1]
            local z = self:_getOppositeVertex(y, x) or 0

            t[1], t[2], t[3] = y, x, z
            local neighbor = search.first(sorted, t, _compareTriangle) or 0
            local hasConstraint = self:_isTriangleEdgeConstrained(x, y)

            local index = 3 * (i - 1) + j
            neighbors[index] = neighbor
            constraints[index] = hasConstraint

            if neighbor <= 0 then
                if hasConstraint then
                    table.insert(self.filter.next, i)
                else
                    table.insert(self.filter.current, i)
                    flags[i] = 1
                end
            end
        end
    end
end

--- @private
function delaunay:_performFilter()
    local flags = self.filter.flags
    local neighbors = self.filter.neighbors
    local constraints = self.filter.constraints
    local current = self.filter.current
    local next = self.filter.next

    local side = 1
    while #current > 0 or #next > 0 do
        while #current > 0 do
            local triangle = table.remove(current, #current)
            if flags[triangle] ~= -side then
                flags[triangle] = side

                for j = 1, 3 do
                    local index = 3 * (triangle - 1) + j
                    local neighbor = neighbors[index]
                    if neighbor > 0 and flags[neighbor] == 0 then
                        if constraints[index] then
                            table.insert(next, neighbor)
                        else
                            table.insert(current, neighbor)
                            flags[neighbor] = side
                        end
                    end
                end
            end
        end

        next, current = current, next
        slicktable.clear(next)
        side = -side
    end
end

--- @private
function delaunay:_skip()
    local unsorted = self.triangulation.unsorted
    local triangles = self.triangulation.triangles

    for i = 1, self.triangulation.n do
        table.insert(triangles, unsorted[i])
    end
end

--- @private
--- @param direction -1 | 0 | 1
function delaunay:_filter(direction)
    if direction == 0 then
        self:_skip()
        return
    end

    self:_sortTriangulation()
    self:_prepareFilter()
    self:_performFilter()

    local flags = self.filter.flags
    local sorted = self.triangulation.sorted
    local result = self.triangulation.triangles

    for i = 1, self.triangulation.n do
        if flags[i] == direction then
            table.insert(result, sorted[i])
        end
    end
end

--- @private
function delaunay:_materialize()
    self.triangulation.n = 0

    for i = 1, self.index.n do
        local vertices = self.index.vertices[i]
        local triangles = self.index.triangles[i]
        if not triangles then
            triangles = {}
            table.insert(self.index.triangles, triangles)
        end

        for j = 1, #vertices, 2 do
            local s = vertices[j]
            local t = vertices[j + 1]

            if i < math.min(s, t) then
                self:_addTriangle(i, s, t)
                table.insert(triangles, self.triangulation.n)
            end
        end
    end
end

--- @private
function delaunay:_buildPolygons()
    local polygons = self.polygonization.polygons
    local triangles = self.triangulation.triangles
    local edges = self.polygonization.edges
    local pending = self.polygonization.pending
    local edgesToPolygons = self.polygonization.edgesToPolygons

    for i, triangle in ipairs(triangles) do
        local polygon = polygons[i]
        if not polygon then
            polygon = {
                vertices = {},
                merged = false
            }

            table.insert(polygons, polygon)
        else
            slicktable.clear(polygon.vertices)
            polygon.merged = false
        end

        for j, vertex in ipairs(triangle) do
            table.insert(polygon.vertices, vertex)

            local a = vertex
            local b = triangle[j % #triangle + 1]
            self.cachedEdge:init(a, b)
            
            local index = search.first(edges, self.cachedEdge, edge.compare)
            if not index then
                index = search.lessThan(edges, self.cachedEdge, edge.compare) + 1
                table.insert(edges, index, self:_newEdge(a, b))
                table.insert(pending, edges[index])
            end
        end
    end
    
    for i = 1, #triangles do
        local polygon = polygons[i]
        local vertices = polygon.vertices
        for j, vertex in ipairs(vertices) do
            local a = vertex
            local b = vertices[j % #vertices + 1]
            self.cachedEdge:init(a, b)

            local index = search.first(edges, self.cachedEdge, edge.compare)
            if index then
                local edgePolygons = edgesToPolygons[index]
                if not edgePolygons then
                    edgePolygons = {}
                    edgesToPolygons[index] = edgePolygons
                end

                table.insert(edgePolygons, polygon)
            else
                if self.debug then
                    assert(false, "critical logic error (edge not found)")
                end
            end
        end
    end

    self.polygonization.n = #triangles
end

--- @private
--- @param polygon slick.geometry.triangulation.delaunayWorkingPolygon
--- @param otherPolygon slick.geometry.triangulation.delaunayWorkingPolygon?
function delaunay:_replacePolygon(polygon, otherPolygon)
    local edges = self.polygonization.edges
    local edgesToPolygons = self.polygonization.edgesToPolygons
    
    local vertices = polygon.vertices
    for i, vertex in ipairs(vertices) do
        local a = vertex
        local b = vertices[i % #vertices + 1]

        self.cachedEdge:init(a, b)

        local index = search.first(edges, self.cachedEdge, edge.compare)
        local polygonsWithEdge = edgesToPolygons[index]
        if polygonsWithEdge then
            local hasOtherPolygon = false
            for j = #polygonsWithEdge, 1, -1 do
                if polygonsWithEdge[j] == otherPolygon then
                    hasOtherPolygon = true
                end
            end

            if not hasOtherPolygon and otherPolygon then
                table.insert(polygonsWithEdge, otherPolygon)
            end
        end
    end
end

--- @private
--- @param destinationPolygon slick.geometry.triangulation.delaunayWorkingPolygon
--- @param sourcePolygon slick.geometry.triangulation.delaunayWorkingPolygon
--- @param destinationPolygonVertexIndex number
--- @param sourcePolygonVertexIndex number
function delaunay:_mergePolygons(destinationPolygon, sourcePolygon, destinationPolygonVertexIndex, sourcePolygonVertexIndex)
    local destinationVertices = destinationPolygon.vertices
    local sourceVertices = sourcePolygon.vertices

    for i = 1, #sourceVertices - 2 do
        local sourceIndex = (i + sourcePolygonVertexIndex) % #sourceVertices + 1
        table.insert(destinationVertices, destinationPolygonVertexIndex + i, sourceVertices[sourceIndex])
    end

    if self.debug then
        local points = self.points

        -- Make sure the polygon is convex.
        local currentSign
        for i, index1 in ipairs(destinationVertices) do
            local index2 = destinationVertices[(i % #destinationVertices) + 1]
            local index3 = destinationVertices[((i + 1) % #destinationVertices) + 1]

            local p1 = points[index1]
            local p2 = points[index2]
            local p3 = points[index3]

            local sign = slickmath.direction(p1, p2, p3)
            if not currentSign then
                currentSign = sign
            end

            assert(currentSign == sign and sign ~= 0, "critical logic error (created concave polygon during polygonization)")
        end
    end

    self:_replacePolygon(sourcePolygon, destinationPolygon)

    sourcePolygon.merged = true
end

--- @private
--- @param destinationPolygon slick.geometry.triangulation.delaunayWorkingPolygon
--- @param sourcePolygon slick.geometry.triangulation.delaunayWorkingPolygon
--- @return boolean
--- @return number
--- @return integer
--- @return integer
function delaunay:_canMergePolygons(destinationPolygon, sourcePolygon)
    if destinationPolygon.merged or sourcePolygon.merged then
        return false, 0, 1, 1
    end

    local destinationVertices = destinationPolygon.vertices
    local sourceVertices = sourcePolygon.vertices
    for j = 1, #destinationVertices do
        local a = destinationVertices[j]
        local b = destinationVertices[j % #destinationVertices + 1]
        local c = destinationVertices[(j - 2) % #destinationVertices + 1]
        local d = destinationVertices[(j + 1) % #destinationVertices + 1]

        for k = 1, #sourceVertices do
            local s = sourceVertices[k]
            local t = sourceVertices[k % #sourceVertices + 1]

            if a == t and b == s then
                local p = sourceVertices[(k + 1) % #sourceVertices + 1]
                local q = sourceVertices[(k + #sourceVertices - 2) % #sourceVertices + 1]

                local p1 = self.points[c]
                local p2 = self.points[a]
                local p3 = self.points[p]
                local p4 = self.points[q]

                local t1 = self.points[b]
                local t2 = self.points[d]

                local s1 = self.points[destinationVertices[1]]
                local s2 = self.points[destinationVertices[2]]
                local s3 = self.points[destinationVertices[3]]

                local signP1 = slickmath.direction(p1, p2, p3)
                local signP2 = slickmath.direction(p4, t1, t2)
                local signS = slickmath.direction(s1, s2, s3)

                if signP1 == signP2 and signP1 == signS then
                    local angle = slickmath.angle(p1, p2, p3)

                    return true, angle, j, k
                end
            end
        end
    end

    return false, 0, 1, 1
end

--- @private
--- @param maxVertexCount number
--- @param result number[][]
--- @return number[][], integer
function delaunay:_polygonize(maxVertexCount, result)
    self:_buildPolygons()

    local pendingEdges = self.polygonization.pending
    local edges = self.polygonization.edges
    local edgesToPolygons = self.polygonization.edgesToPolygons

    while #pendingEdges > 0 do
        local e = table.remove(pendingEdges, #pendingEdges)
        local index = search.first(edges, e, edge.compare)

        local bestMagnitude
        local sourcePolygonIndex, destinationPolygonIndex
        local sourcePolygonVertexIndex, destinationPolygonVertexIndex

        -- This might look N^2 but there's only ever two polygons that share an edge so it's just... O(1)
        local polygons = edgesToPolygons[index]
        for i = 1, #polygons do
            for j = i + 1, #polygons do
                local canMerge, magnitude, s, t = self:_canMergePolygons(polygons[i], polygons[j])
                if canMerge then
                    if magnitude > (bestMagnitude or -math.huge) then
                        bestMagnitude = magnitude
                        destinationPolygonIndex = i
                        sourcePolygonIndex = j
                        destinationPolygonVertexIndex = s
                        sourcePolygonVertexIndex = t
                    end
                end
            end
        end

        if bestMagnitude then
            local destinationPolygon = polygons[destinationPolygonIndex]
            local sourcePolygon = polygons[sourcePolygonIndex]

            -- 2 vertices are shared between the polygons.
            -- So when merging them, there's actually two less than their combined sum.
            -- E.g., a triangle would have one edge shared with another triangle - so:
            --   - 1 vertex from the destination triangle
            --   - 1 vertex from the source triangle
            --   - 2 shared forming the shared edge from destination and source (so 4 vertex indices total),
            -- If we just counted the sum of the vertex arrays, we'd get 6, which is incorrect.
            -- The new polygon would have 4 vertices!
            if #destinationPolygon.vertices + #sourcePolygon.vertices - 2 <= maxVertexCount then
                self:_mergePolygons(destinationPolygon, sourcePolygon, destinationPolygonVertexIndex, sourcePolygonVertexIndex)
            end
        end
    end

    local polygons = self.polygonization.polygons

    local index = 0
    for i = 1, self.polygonization.n do
        if not polygons[i].merged then
            index = index + 1

            local outputPolygon = result[index]
            if not outputPolygon then
                outputPolygon = {}
                table.insert(result, outputPolygon)
            else
                slicktable.clear(outputPolygon)
            end

            local inputPolygon = polygons[i]
            for _, vertex in ipairs(inputPolygon.vertices) do
                table.insert(outputPolygon, vertex)
            end

            self:_replacePolygon(inputPolygon, nil)
        end
    end

    return result, index
end

function delaunay:reset()
    self.pointsPool:reset()
    self.sortedPointsPool:reset()
    self.segmentsPool:reset()
    self.edgesPool:reset()
    self.sortedEdgesPool:reset()
    self.sweepPool:reset()
    self.hullsPool:reset()

    slicktable.clear(self.points)
    slicktable.clear(self.sortedPoints)
    slicktable.clear(self.temporaryEdges)
    slicktable.clear(self.edges)
    slicktable.clear(self.sortedEdges)
    slicktable.clear(self.sweeps)
    slicktable.clear(self.hulls)
    
    self.triangulation.n = 0
    slicktable.clear(self.triangulation.sorted)
    slicktable.clear(self.triangulation.triangles)
    
    slicktable.clear(self.filter.flags)
    slicktable.clear(self.filter.neighbors)
    slicktable.clear(self.filter.constraints)
    slicktable.clear(self.filter.current)
    slicktable.clear(self.filter.next)
    
    self.index.n = 0
    slicktable.clear(self.index.stack)
    
    self.polygonization.n = 0
    slicktable.clear(self.polygonization.edges)
    slicktable.clear(self.polygonization.pending)
    
    for i = 1, #self.polygonization.edgesToPolygons do
        slicktable.clear(self.polygonization.edgesToPolygons[i])
    end
    
    for i = 1, #self.index.vertices do
        slicktable.clear(self.index.vertices[i])
    end
    
    for i = 1, #self.index.triangles do
        slicktable.clear(self.index.triangles[i])
    end
end

function delaunay:clear()
    self:reset()

    self.pointsPool:clear()
    self.sortedPointsPool:clear()
    self.segmentsPool:clear()
    self.edgesPool:clear()
    self.sortedEdgesPool:clear()
    self.sweepPool:clear()
    self.hullsPool:clear()
    
    slicktable.clear(self.polygonization.polygons)
    slicktable.clear(self.polygonization.edgesToPolygons)
    
    slicktable.clear(self.activeEdges)
    slicktable.clear(self.temporaryEdges)
    slicktable.clear(self.pendingEdges)
    slicktable.clear(self.sortedEdges)
    slicktable.clear(self.sortedPoints)

    slicktable.clear(self.index.vertices)
    slicktable.clear(self.triangulation.unsorted)
end

--- @private
--- @param x number
--- @param y number
--- @return slick.geometry.point
function delaunay:_newPoint(x, y)
    --- @type slick.geometry.point
    return self.pointsPool:allocate(x, y)
end

--- @private
--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @return slick.geometry.segment
function delaunay:_newSegment(a, b)
    --- @type slick.geometry.segment
    return self.segmentsPool:allocate(a, b)
end

--- @private
--- @param a number
--- @param b number
--- @return slick.geometry.triangulation.edge
function delaunay:_newEdge(a, b)
    --- @type slick.geometry.triangulation.edge
    return self.edgesPool:allocate(a, b)
end

--- @private
--- @param e slick.geometry.triangulation.edge
--- @param segment slick.geometry.segment
--- @return slick.geometry.triangulation.delaunaySortedEdge
function delaunay:_newSortedEdge(e, segment)
    assert(self.points[e.a]:equal(segment.a) or self.points[e.a]:equal(segment.b))
    assert(self.points[e.b]:equal(segment.a) or self.points[e.b]:equal(segment.b))

    --- @type slick.geometry.triangulation.delaunaySortedEdge
    return self.sortedEdgesPool:allocate(e, segment)
end

--- @private
--- @param index number
--- @return slick.geometry.triangulation.delaunaySortedPoint
function delaunay:_newSortedPoint(index)
    --- @type slick.geometry.triangulation.delaunaySortedPoint
    return self.sortedPointsPool:allocate(self.points[index], index)
end

--- @private
--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param index number
--- @return slick.geometry.triangulation.hull
function delaunay:_newHull(a, b, index)
    --- @type slick.geometry.triangulation.hull
    return self.hullsPool:allocate(a, b, index)
end

--- @private
--- @param x number
--- @param y number
function delaunay:_addPoint(x, y)
    table.insert(self.points, self:_newPoint(x, y))

    local edges = self.pointsToEdges[#self.points]
    if not edges then
        self.pointsToEdges[#self.points] = {}
    else
        slicktable.clear(edges)
    end
end

--- @private
--- @param edgeA number
--- @param edgeB number
function delaunay:_addEdge(edgeA, edgeB)
    assert(edgeA ~= edgeB)

    local e = self:_newEdge(edgeA, edgeB)
    table.insert(self.edges, search.lessThan(self.edges, e, edge.compare) + 1, e)

    local a = self.pointsToEdges[e.a]
    if not a then
        a = {}
        self.pointsToEdges[e.a] = a
    end

    table.insert(a, search.lessThan(a, e, edge.compare) + 1, e)

    local b = self.pointsToEdges[e.b]
    if not b then
        b = {}
        self.pointsToEdges[e.b] = b
    end

    table.insert(b, search.lessThan(b, e, edge.compare) + 1, e)
end

function delaunay:_addSortedEdge(a, b)
    assert(a ~= b)

    self.cachedEdge:init(a, b)
    self.cachedSegment:init(self.points[a], self.points[b])

    local index = search.lessThan(self.sortedEdges, self.cachedSegment, delaunaySortedEdge.compareSegment)
    table.insert(self.sortedEdges, index + 1, self:_newSortedEdge(self.cachedEdge, self.cachedSegment))
end

--- @private
--- @param edgeA number
--- @param edgeB number
function delaunay:_dissolveSortedEdge(edgeA, edgeB)
    local sortedEdges = self.sortedEdges

    self.cachedSegment:init(self.points[edgeA], self.points[edgeB])
    local start = search.first(sortedEdges, self.cachedSegment, delaunaySortedEdge.compareSegment)
    local stop = start and search.last(sortedEdges, self.cachedSegment, delaunaySortedEdge.compareSegment, start)

    assert(start and stop)

    local dissolved = false
    for j = stop, start, -1 do
        local sortedEdge = sortedEdges[j]
        if sortedEdge.edge.min == math.min(edgeA, edgeB) and sortedEdge.edge.max == math.max(edgeA, edgeB) then
            dissolved = true
            self.sortedEdgesPool:deallocate(table.remove(sortedEdges, j))
            break
        end
    end

    assert(dissolved)
end

--- @private
--- @param edgeA number
--- @param edgeB number
function delaunay:_dissolveEdge(edgeA, edgeB)
    self.cachedEdge:init(edgeA, edgeB)

    local edgeIndex = search.first(self.edges, self.cachedEdge, edge.compare)
    assert(edgeIndex)

    local e
    while edgeIndex do
        e = table.remove(self.edges, edgeIndex)

        assert(e.min == math.min(edgeA, edgeB))
        assert(e.max == math.max(edgeA, edgeB))

        local a = self.pointsToEdges[e.a]
        if a then
            local index = search.first(a, e, edge.compare)
            assert(index)

            table.remove(a, index)
        end

        local b = self.pointsToEdges[e.b]
        if b then
            local index = search.first(b, e, edge.compare)
            assert(index)

            table.remove(b, index)
        end

        self:_dissolveSortedEdge(edgeA, edgeB)

        edgeIndex = search.first(self.edges, self.cachedEdge, edge.compare)
    end

    self.edgesPool:deallocate(e)
end

--- @private
--- @param i number
--- @param j number
--- @param k number
function delaunay:_addTriangle(i, j, k)
    local index = self.triangulation.n + 1
    local unsorted = self.triangulation.unsorted

    if index > #unsorted then
        local triangle = { i, j, k }
        table.insert(unsorted, triangle)
    else
        local triangle = unsorted[index]
        triangle[1], triangle[2], triangle[3] = i, j, k
    end

    self.triangulation.n = index
end

--- @private
--- @param sweepType slick.geometry.triangulation.sweepType
--- @param data slick.geometry.point | slick.geometry.segment
--- @param index number
function delaunay:_addSweep(sweepType, data, index)
    --- @type slick.geometry.triangulation.sweep
    local event = self.sweepPool:allocate(sweepType, data, index)
    table.insert(self.sweeps, event)
    return event
end

--- @private
--- @param points number[]
--- @param point slick.geometry.point
--- @param index number
--- @param swap boolean
--- @param compare fun(value: number): boolean
function delaunay:_addPointToHull(points, point, index, swap, compare)
    for i = #points, 2, -1 do
        local index1 = points[i - 1]
        local index2 = points[i]

        local point1 = self.points[index1]
        local point2 = self.points[index2]

        if compare(slickmath.direction(point1, point2, point, self.epsilon)) then
            if swap then
                index1, index2 = index2, index1
            end

            self:_addTriangle(index1, index2, index)
            table.remove(points, i)
        end
    end

    table.insert(points, index)
end

--- @private
--- @param point slick.geometry.point
--- @param index number
function delaunay:_addPointToHulls(point, index)
    local lowIndex = search.lessThan(self.hulls, point, hull.point)
    local highIndex = search.greaterThan(self.hulls, point, hull.point)
    
    if self.debug then
        assert(lowIndex, "hull for lower bound not found")
        assert(highIndex, "hull for upper bound not found")
    end
    
    for i = lowIndex, highIndex - 1 do
        local hull = self.hulls[i]

        self:_addPointToHull(hull.lowerPoints, point, index, true, _greaterThanZero)
        self:_addPointToHull(hull.higherPoints, point, index, false, _lessThanZero)
    end
end

--- @private
--- @param sweep slick.geometry.triangulation.sweep
function delaunay:_splitHulls(sweep)
    local index = search.lessThanEqual(self.hulls, sweep, hull.sweep)
    local hull = self.hulls[index]

    local otherHull = self:_newHull(sweep.data.a, sweep.data.b, sweep.index)
    for _, otherPoint in ipairs(hull.higherPoints) do
        table.insert(otherHull.higherPoints, otherPoint)
    end

    local otherPoint = hull.higherPoints[#hull.higherPoints]
    table.insert(otherHull.lowerPoints, otherPoint)

    slicktable.clear(hull.higherPoints)
    table.insert(hull.higherPoints, otherPoint)

    table.insert(self.hulls, index + 1, otherHull)
end

--- @private
--- @param sweep slick.geometry.triangulation.sweep
function delaunay:_mergeHulls(sweep)
    sweep.data.a, sweep.data.b = sweep.data.b, sweep.data.a

    local index = search.last(self.hulls, sweep, hull.sweep)
    local upper = self.hulls[index]
    local lower = self.hulls[index - 1]

    lower.higherPoints, upper.higherPoints = upper.higherPoints, lower.higherPoints

    table.remove(self.hulls, index)
    self.hullsPool:deallocate(upper)
end

return delaunay
