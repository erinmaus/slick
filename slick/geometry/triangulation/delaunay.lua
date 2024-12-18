local point = require("slick.geometry.point")
local segment = require("slick.geometry.segment")
local dissolve = require("slick.geometry.triangulation.dissolve")
local edge = require("slick.geometry.triangulation.edge")
local hull = require("slick.geometry.triangulation.hull")
local intersection = require("slick.geometry.triangulation.intersection")
local sweep = require("slick.geometry.triangulation.sweep")
local pool = require("slick.util.pool")
local search = require("slick.util.search")
local slickmath = require("slick.util.slickmath")
local slicktable = require("slick.util.slicktable")

--- @class slick.geometry.triangulation.delaunayTriangulationOptions
--- @field public refine boolean?
--- @field public interior boolean?
--- @field public exterior boolean?
local defaultTriangulationOptions = {
    refine = true,
    interior = true,
    exterior = false
}

--- @alias slick.geometry.triangulation.intersectFunction fun(intersection: slick.geometry.triangulation.intersection)
--- @alias slick.geometry.triangulation.dissolveFunction fun(dissolve: slick.geometry.triangulation.dissolve)

--- @class slick.geometry.triangulation.delaunayCleanupOptions
--- @field public intersect slick.geometry.triangulation.intersectFunction?
--- @field public dissolve slick.geometry.triangulation.dissolveFunction?
local defaultCleanupOptions = {
    intersect = intersection.default,
    dissolve = dissolve.default,
}

--- @alias slick.geometry.triangulation.delaunaySortedPoint { point: slick.geometry.point, id: number, newID: number?, dissolve: boolean? }

--- @class slick.geometry.triangulation.delaunay
--- @field private epsilon number
--- @field private debug boolean
--- @field private pointsPool slick.util.pool
--- @field private points slick.geometry.point[]
--- @field private sortedPoints slick.geometry.triangulation.delaunaySortedPoint[]
--- @field private intersection slick.geometry.triangulation.intersection
--- @field private dissolve slick.geometry.triangulation.dissolve
--- @field private sortedPointCompareFunc fun(a: slick.geometry.triangulation.delaunaySortedPoint, b: slick.geometry.triangulation.delaunaySortedPoint): slick.util.search.compareResult
--- @field private sortedPointLessFunc fun(a: slick.geometry.triangulation.delaunaySortedPoint, b: slick.geometry.triangulation.delaunaySortedPoint): boolean
--- @field private segmentsPool slick.util.pool
--- @field private edgesPool slick.util.pool
--- @field private cachedEdge slick.geometry.triangulation.edge
--- @field private temporaryEdges slick.geometry.triangulation.edge[]
--- @field private edges slick.geometry.triangulation.edge[]
--- @field private sweepPool slick.util.pool
--- @field private sweeps slick.geometry.triangulation.sweep[]
--- @field private sweepCompareFunc slick.geometry.triangulation.sweepCompareFunc
--- @field private hullsPool slick.util.pool
--- @field private hulls slick.geometry.triangulation.hull[]
--- @field private hullPointCompareFunc slick.geometry.triangulation.hullPointCompareFunc
--- @field private hullSweepCompareFunc slick.geometry.triangulation.hullSweepCompareFunc
--- @field private cachedTriangle number[]
--- @field private triangulation { n: number, triangles: number[][], sorted: number[][], unsorted: number[][] }
--- @field private filter { flags: number[], neighbors: number[], constraints: boolean[], current: number[], next: number[] }
--- @field private index { n: number, vertices: number[][], stack: number[] }
--- @field private userdata any[]
local delaunay = {}
local metatable = { __index = delaunay }

local default = {
    epsilon = slickmath.EPSILON,
    debug = false
}

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

--- @param a slick.geometry.triangulation.delaunaySortedPoint
--- @param b slick.geometry.triangulation.delaunaySortedPoint
local function _lessSortedPointID(a, b)
    if a.id > 0 and a.id > 0 then
        return a.id < b.id
    else
        return a.id > b.id
    end
end

--- @param t { epsilon?: number }?
function delaunay.new(t)
    t = t or default
    local epsilon = t.epsilon or slickmath.EPSILON
    local debug = not not t.debug

    --- @param a slick.geometry.triangulation.delaunaySortedPoint
    --- @param b slick.geometry.triangulation.delaunaySortedPoint
    local function sortedPointCompareFunc(a, b)
        if a.id > 0 and b.id > 0 then
            if a.point:lessThan(b.point, epsilon) then
                return -1
            elseif a.point:equal(b.point, epsilon) then
                return a.id - b.id
            end

            return 1
        end

        return a.id > b.id
    end

    --- @param a slick.geometry.triangulation.delaunaySortedPoint
    --- @param b slick.geometry.triangulation.delaunaySortedPoint
    local function sortedPointLessFunc(a, b)
        return sortedPointCompareFunc(a, b) < 0
    end

    return setmetatable({
        epsilon = epsilon,
        debug = debug,

        pointsPool = pool.new(point),
        points = {},

        intersection = intersection.new(),
        dissolve = dissolve.new(),

        sortedPointCompareFunc = sortedPointCompareFunc,
        sortedPointLessFunc = sortedPointLessFunc,
        sortedPoints = {},

        segmentsPool = pool.new(segment),
        edgesPool = pool.new(edge),
        temporaryEdges = {},
        cachedEdge = edge.new(0, 0),
        edges = {},

        sweepCompareFunc = sweep.less(epsilon),
        sweepPool = pool.new(sweep),
        sweeps = {},

        hullsPool = pool.new(hull),
        hulls = {},
        hullPointCompareFunc = hull.point(epsilon),
        hullSweepCompareFunc = hull.sweep(epsilon),

        cachedTriangle = { 0, 0, 0 },
        triangulation = { n = 0, triangles = {}, sorted = {}, unsorted = {} },
        filter = { flags = {}, neighbors = {}, constraints = {}, current = {}, next = {} },
        index = { n = 0, vertices = {}, stack = {} }
    }, metatable)
end

--- @private
--- @param dissolve slick.geometry.triangulation.dissolveFunction
--- @return boolean
function delaunay:_dedupePoints(dissolve, userdata)
    local didDedupe = false

    local sortedPoints = self.sortedPoints
    local edges = self.edges

    local index = 1
    while index < #sortedPoints do
        local sortedPoint = sortedPoints[index]

        local start = index
        local stop = search.last(sortedPoints, sortedPoint, self.sortedPointCompareFunc, start)

        for i = start + 1, stop do
            sortedPoints[i].dissolve = true

            self.dissolve:init(sortedPoint.point, sortedPoint.id, userdata and userdata[sortedPoint.id])
            dissolve(self.dissolve)
            
            for j = #edges, 1, -1 do
                local e = edges[j]

                if e.a == i or e.b == i then
                    table.remove(edges, j)

                    if e.a == index then
                        e:init(start, e.b)
                    elseif e.b == index then
                        e:init(edge.a, start)
                    end

                    local edgeIndex = search.lessThan(edges, e, edge.compare)
                    table.insert(edges, edgeIndex + 1, e)
                end
            end
        end

        index = index + 1
        didDedupe = didDedupe or stop > start
    end

    return didDedupe
end

--- @private
--- @return boolean
function delaunay:_dedupeEdges()
    local didDedupe = false
    local edges = self.edges

    local index = 1
    while index < #edges do
        local e = edges[index]
        
        if e.a == e.b then
            didDedupe = true

            table.remove(edges, index)
        else
            local start = index
            local stop = search.last(edges, e, edge.compare, start)

            for i = stop, start + 1, -1 do
                table.remove(edges, i)
            end
            
            index = index + 1
            didDedupe = didDedupe or stop > start
        end
    end

    return didDedupe
end

--- @private
--- @param intersect slick.geometry.triangulation.intersectFunction
--- @param userdata any[]?
--- @return boolean
function delaunay:_stepClean(intersect, userdata)
    local isDirty = false

    local points = self.points
    local sortedPoints = self.sortedPoints
    local edges = self.edges
    local temporaryEdges = self.temporaryEdges

    slicktable.clear(temporaryEdges)

    -- Split edges that a point is collinear with
    for i = 1, #points do
        local point = sortedPoints[i]

        if not point.dissolve then
            for i = #edges, 1, -1 do
                local e = edges[i]
                local a = points[e.a]
                local b = points[e.b]

                if e.a ~= point.id and e.b ~= point.id then
                    local intersection, x, y = slickmath.intersection(a, b, point.point, point.point, self.epsilon)
                    if intersection and not (x and y) then
                        isDirty = true

                        local newEdge1 = self:_newEdge(e.a, point.id)
                        local newEdge2 = self:_newEdge(point.id, e.b)

                        table.insert(temporaryEdges, newEdge1)
                        table.insert(temporaryEdges, newEdge2)

                        table.remove(edges, i)
                        self.edgesPool:deallocate(e)
                    end
                end
            end
        end
    end

    for _, e in ipairs(temporaryEdges) do
        local index = search.lessThan(edges, e, edge.compare)
        table.insert(edges, index + 1, e)
    end

    slicktable.clear(temporaryEdges)

    -- Split edges that cross
    for i = #edges, 1, -1 do
        local selfEdge = edges[i]

        local j = i + 1
        while j < #edges do
            local otherEdge = edges[j]
            if not (selfEdge.a == otherEdge.a or selfEdge.a == otherEdge.b or selfEdge.b == otherEdge.a or selfEdge.b == otherEdge.b) then
                local a1 = points[selfEdge.a]
                local b1 = points[selfEdge.b]
                local a2 = points[otherEdge.a]
                local b2 = points[otherEdge.b]

                local intersection, x, y = slickmath.intersection(a1, b1, a2, b2, self.epsilon)
                
                if intersection then
                    isDirty = true

                    if not (x and y) then
                        -- Edges are collinear. Delete the other edge.
                        -- TODO: Split edge?

                        table.remove(edges, j)
                        self.edgesPool:deallocate(otherEdge)
                    else
                        -- Edges intersect.
                        self:_addPoint(x, y)

                        local point = points[#points]
                        local sortedPoint = sortedPoints[#points]
                        if not sortedPoint then
                            sortedPoint = {}
                            table.insert(self.sortedPoints, sortedPoint)
                        end

                        sortedPoint.id = #points
                        sortedPoint.point = self:_newPoint(x, y)
                        sortedPoint.newID = nil
                        sortedPoint.dissolve = false

                        table.insert(self.temporaryEdges, self:_newEdge(selfEdge.a, sortedPoint.id))
                        table.insert(self.temporaryEdges, self:_newEdge(sortedPoint.id, selfEdge.b))
                        table.insert(self.temporaryEdges, self:_newEdge(otherEdge.a, sortedPoint.id))
                        table.insert(self.temporaryEdges, self:_newEdge(sortedPoint.id, otherEdge.b))
                        
                        self.intersection:init(#points)

                        self.intersection:setLeftEdge(
                            a1, b1,
                            userdata and userdata[selfEdge.a],
                            userdata and userdata[selfEdge.b])
                            
                        self.intersection:setRightEdge(
                            a2, b2,
                            userdata and userdata[otherEdge.a],
                            userdata and userdata[otherEdge.b])
                            
                        self.intersection:computeDelta(self.epsilon)
                        self.intersection.result:init(point.x, point.y)

                        intersect(self.intersection)
                        point:init(self.intersection.result.x, self.intersection.result.y)
                        
                        table.remove(edges, math.max(i, j))
                        table.remove(edges, math.min(i, j))
                    end
                else
                    j = j + 1
                end
            else
                j = j + 1
            end
        end
    end

    for _, e in ipairs(temporaryEdges) do
        local index = search.lessThan(edges, e, edge.compare)
        table.insert(edges, index + 1, e)
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

    local dissolve = options.dissolve == nil and defaultCleanupOptions.dissolve or options.dissolve
    local intersect = options.intersect == nil and defaultCleanupOptions.intersect or options.intersect

    self:reset()

    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        self:_addPoint(x, y)

        local index = #self.points
        local sortedPoint = self.sortedPoints[index]
        if not sortedPoint then
            sortedPoint = {}
            self.sortedPoints[index] = sortedPoint
        end

        sortedPoint.id = index
        sortedPoint.point = self:_newPoint(x, y)
        sortedPoint.newID = nil
        sortedPoint.dissolve = false
    end

    for i = #points + 1, #self.sortedPoints do
        local sortedPoint = self.sortedPoints[i]
        sortedPoint.id = 0
    end

    if edges then
        for i = 1, #edges, 2 do
            local p1 = edges[i]
            local p2 = edges[i + 1]
            self:_addEdge(p1, p2)
        end

        table.sort(self.edges, edge.less)
    end

    local continue
    repeat
        table.sort(self.sortedPoints, self.sortedPointLessFunc)
        self:_dedupePoints(dissolve, userdata)
        self:_dedupeEdges()
        continue = self:_stepClean(intersect, userdata)
    until not continue

    slicktable.clear(points)
    slicktable.clear(edges)

    table.sort(self.sortedPoints, _lessSortedPointID)

    outPoints = outPoints or {}
    outEdges = outEdges or {}
    outUserdata = outUserdata or {}

    slicktable.clear(outPoints)
    slicktable.clear(outEdges)
    slicktable.clear(outUserdata)

    local currentPointIndex = 1
    for i = 1, #self.sortedPoints do
        local sortedPoint = self.sortedPoints[i]
        if not sortedPoint.dissolve then
            sortedPoint.newID = currentPointIndex
            currentPointIndex = currentPointIndex + 1

            table.insert(outPoints, sortedPoint.point.x)
            table.insert(outPoints, sortedPoint.point.y)

            if userdata then
                table.insert(outUserdata, userdata[sortedPoint.id])
            end
        end
    end

    for i = 1, #self.edges do
        local e = self.edges[i]
        local a = self.sortedPoints[e.a]
        local b = self.sortedPoints[e.b]

        if not (a.dissolve or b.dissolve) then
            table.insert(outEdges, a.newID)
            table.insert(outEdges, b.newID)
        end
    end

    return outPoints, outEdges, outUserdata
end

--- @param points number[]
--- @param edges number[]
--- @param options slick.geometry.triangulation.delaunayTriangulationOptions
--- @param result number[][]?
function delaunay:triangulate(points, edges, options, result)
    options = options or defaultTriangulationOptions

    local refine = options.refine == nil and defaultTriangulationOptions.refine or options.refine
    local interior = options.interior == nil and defaultTriangulationOptions.interior or options.interior
    local exterior = options.exterior == nil and defaultTriangulationOptions.exterior or options.exterior

    self:reset()

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

        table.sort(self.edges, edge.less)
    end

    self:_sweep()
    self:_triangulate()

    if refine or interior or exterior then
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

    return result, #triangles
end

--- @private
function delaunay:_sweep()
    for i, point in ipairs(self.points) do
        self:_addSweep(sweep.TYPE_POINT, point, i)
    end

    for i, edge in ipairs(self.edges) do
        local a, b = self.points[edge.a], self.points[edge.b]
        if not a:lessThan(b, self.epsilon) then
            a, b = b, a
        end

        self:_addSweep(sweep.TYPE_EDGE_START, self:_newSegment(a, b), i)
        self:_addSweep(sweep.TYPE_EDGE_STOP, self:_newSegment(b, a), i)
    end

    table.sort(self.sweeps, self.sweepCompareFunc)
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
        self.points[y],
        self.epsilon)
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

            if second > first and not self:_isTriangleEdgeConstrained(first, second) then
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
                        self.points[y],
                        self.epsilon)

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
                self.points[y],
                self.epsilon)

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
                            flags[triangle] = side
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
        for j = 1, #vertices, 2 do
            local s = vertices[j]
            local t = vertices[j + 1]

            if i < math.min(s, t) then
                self:_addTriangle(i, s, t)
            end
        end
    end
end

function delaunay:reset()
    self.pointsPool:reset()
    self.segmentsPool:reset()
    self.edgesPool:reset()
    self.sweepPool:reset()
    self.hullsPool:reset()

    slicktable.clear(self.points)
    slicktable.clear(self.temporaryEdges)
    slicktable.clear(self.edges)
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
end

function delaunay:clear()
    self:reset()

    self.pointsPool:clear()
    self.segmentsPool:clear()
    self.edgesPool:clear()
    self.sweepPool:clear()
    self.hullsPool:clear()

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
end

--- @private
--- @param a number
--- @param b number
function delaunay:_addEdge(a, b)
    table.insert(self.edges, self:_newEdge(a, b))
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
    local lowIndex = search.lessThan(self.hulls, point, self.hullPointCompareFunc)
    local highIndex = search.greaterThan(self.hulls, point, self.hullPointCompareFunc)
    
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
    local index = search.lessThanEqual(self.hulls, sweep, self.hullSweepCompareFunc)
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

    local index = search.last(self.hulls, sweep, self.hullSweepCompareFunc)
    local upper = self.hulls[index]
    local lower = self.hulls[index - 1]

    lower.higherPoints, upper.higherPoints = upper.higherPoints, lower.higherPoints

    table.remove(self.hulls, index)
    self.hullsPool:deallocate(upper)
end

return delaunay