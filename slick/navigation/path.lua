local point  = require "slick.geometry.point"
local segment = require "slick.geometry.segment"
local edge = require "slick.navigation.edge"
local vertex = require "slick.navigation.vertex"
local slicktable = require "slick.util.slicktable"
local slickmath  = require "slick.util.slickmath"

--- @class slick.navigation.pathOptions
--- @field optimize boolean?
--- @field neighbor nil | fun(from: slick.navigation.triangle, to: slick.navigation.triangle, e: slick.navigation.edge): boolean
--- @field neighbors nil | fun(mesh: slick.navigation.mesh, triangle: slick.navigation.triangle): slick.navigation.triangle[] | nil
--- @field distance nil | fun(from: slick.navigation.triangle, to: slick.navigation.triangle, e: slick.navigation.edge): number
--- @field heuristic nil | fun(triangle: slick.navigation.triangle, goalX: number, goalY: number): number
--- @field visit nil | fun(from: slick.navigation.triangle, to: slick.navigation.triangle, e: slick.navigation.edge): boolean?
--- @field yield nil | fun(): boolean?
local defaultPathOptions = {
    optimize = true
}

--- @param from slick.navigation.triangle
--- @param to slick.navigation.triangle
--- @param e slick.navigation.edge
--- @return boolean
function defaultPathOptions.neighbor(from, to, e)
    return true
end

--- @param mesh slick.navigation.mesh
--- @param triangle slick.navigation.triangle
--- @return slick.navigation.edge[] | nil
function defaultPathOptions.neighbors(mesh, triangle)
    return mesh:getTriangleNeighbors(triangle.index)
end

local _distanceEdgeSegment = segment.new()
local _distanceEdgeCenter = point.new()
--- @param from slick.navigation.triangle
--- @param to slick.navigation.triangle
--- @param e slick.navigation.edge
function defaultPathOptions.distance(from, to, e)
    _distanceEdgeSegment:init(e.a.point, e.b.point)
    _distanceEdgeSegment:lerp(0.5, _distanceEdgeCenter)
    return from.centroid:distance(_distanceEdgeCenter) + to.centroid:distance(_distanceEdgeCenter)
end


--- @param triangle slick.navigation.triangle
--- @param goalX number
--- @param goalY number
--- @return number
function defaultPathOptions.heuristic(triangle, goalX, goalY)
    return math.sqrt((triangle.centroid.x - goalX) ^ 2 + (triangle.centroid.y - goalY) ^ 2)
end

function defaultPathOptions.yield()
    -- Nothing.
end

function defaultPathOptions.visit(triangle, e)
    -- Nothing.
end

--- @class slick.navigation.impl.pathBehavior
--- @field start slick.navigation.triangle | nil
--- @field goal slick.navigation.triangle | nil
local internalPathBehavior = {}

--- @class slick.navigation.path
--- @field private options slick.navigation.pathOptions
--- @field private behavior slick.navigation.impl.pathBehavior
--- @field private fScores table<slick.navigation.triangle, number>
--- @field private gScores table<slick.navigation.triangle, number>
--- @field private hScores table<slick.navigation.triangle, number>
--- @field private visitedEdges table<slick.navigation.edge, true>
--- @field private visitedTriangles table<slick.navigation.triangle, true>
--- @field private pending slick.navigation.triangle[]
--- @field private closed slick.navigation.triangle[]
--- @field private neighbors slick.navigation.triangle[]
--- @field private graph table<slick.navigation.triangle, slick.navigation.triangle>
--- @field private path slick.navigation.edge[]
--- @field private portals slick.navigation.vertex[]
--- @field private funnel slick.navigation.vertex[]
--- @field private result slick.navigation.vertex[]
--- @field private startVertex slick.navigation.vertex
--- @field private goalVertex slick.navigation.vertex
--- @field private startEdge slick.navigation.edge
--- @field private goalEdge slick.navigation.edge
--- @field private sharedStartGoalEdge slick.navigation.edge
--- @field private _sortFScoreFunc fun(a: slick.navigation.triangle, b: slick.navigation.triangle): boolean
--- @field private _sortHScoreFunc fun(a: slick.navigation.triangle, b: slick.navigation.triangle): boolean
local path = {}
local metatable = { __index = path }

--- @param options slick.navigation.pathOptions?
function path.new(options)
    options = options or defaultPathOptions

    local self = setmetatable({
        options = {
            optimize = options.optimize == nil and defaultPathOptions.optimize or not not options.optimize,
            neighbor = options.neighbor or defaultPathOptions.neighbor,
            neighbors = options.neighbors or defaultPathOptions.neighbors,
            distance = options.distance or defaultPathOptions.distance,
            heuristic = options.heuristic or defaultPathOptions.heuristic,
            visit = options.visit or defaultPathOptions.visit,
            yield = options.yield or defaultPathOptions.yield,
        },

        behavior = {},

        fScores = {},
        gScores = {},
        hScores = {},
        visitedEdges = {},
        visitedTriangles = {},
        pending = {},
        closed = {},
        neighbors = {},
        graph = {},
        path = {},
        portals = {},
        funnel = {},
        result = {},

        startVertex = vertex.new(point.new(0, 0), nil, -1),
        goalVertex = vertex.new(point.new(0, 0), nil, -2),
    }, metatable)

    self.startEdge = edge.new(self.startVertex, self.startVertex)
    self.goalEdge = edge.new(self.goalVertex, self.goalVertex)
    self.sharedStartGoalEdge = edge.new(self.startVertex, self.goalVertex)

    function self._sortFScoreFunc(a, b)
        --- @diagnostic disable-next-line: invisible
        return (self.fScores[a] or math.huge) > (self.fScores[b] or math.huge)
    end

    function self._sortHScoreFunc(a, b)
        --- @diagnostic disable-next-line: invisible
        return (self.hScores[a] or math.huge) > (self.hScores[b] or math.huge)
    end

    return self
end

--- @private
--- @param mesh slick.navigation.mesh
--- @param triangle slick.navigation.triangle
--- @return slick.navigation.triangle[]
function path:_neighbors(mesh, triangle)
    slicktable.clear(self.neighbors)

    local neighbors = self.options.neighbors(mesh, triangle)
    if neighbors then
        for _, neighbor in ipairs(neighbors) do
            if self.options.neighbor(triangle, neighbor, mesh:getSharedTriangleEdge(triangle, neighbor)) then
                table.insert(self.neighbors, neighbor)
            end
        end
    end

    return self.neighbors
end

--- @private
function path:_reset()
    slicktable.clear(self.fScores)
    slicktable.clear(self.gScores)
    slicktable.clear(self.hScores)
    slicktable.clear(self.visitedEdges)
    slicktable.clear(self.visitedTriangles)
    slicktable.clear(self.pending)
    slicktable.clear(self.graph)
end

--- @private
function path:_funnel()
    slicktable.clear(self.funnel)
    slicktable.clear(self.portals)

    table.insert(self.portals, self.path[1].a)
    table.insert(self.portals, self.path[1].a)
    for i = 2, #self.path - 1 do
        local p = self.path[i]

        local C, D = p.a, p.b
        local L, R = self.portals[#self.portals - 1], self.portals[#self.portals]

        local sign = slickmath.direction(D.point, C.point, L.point, slickmath.EPSILON)
        sign = sign == 0 and slickmath.direction(D.point, C.point, R.point, slickmath.EPSILON) or sign

        if sign > 0 then
            table.insert(self.portals, D)
            table.insert(self.portals, C)
        else
            table.insert(self.portals, C)
            table.insert(self.portals, D)
        end
    end
    table.insert(self.portals, self.path[#self.path].b)
    table.insert(self.portals, self.path[#self.path].b)

    local apex, left, right = self.portals[1], self.portals[1], self.portals[2]
    local leftIndex, rightIndex = 1, 1

    table.insert(self.funnel, apex)

    local n = #self.portals / 2
    local index = 2
    while index <= n do
        local i = (index - 1) * 2 + 1
        local j = i + 1

        local otherLeft = self.portals[i]
        local otherRight = self.portals[j]

        local skip = false
        if slickmath.direction(right.point, otherRight.point, apex.point, slickmath.EPSILON) <= 0 then
            if apex.index == right.index or slickmath.direction(left.point, otherRight.point, apex.point, slickmath.EPSILON) > 0 then
                right = otherRight
                rightIndex = index
            else
                table.insert(self.funnel, left)
                apex = left
                right = left

                rightIndex = leftIndex

                index = leftIndex
                skip = true
            end
        end

        if not skip and slickmath.direction(left.point, otherLeft.point, apex.point, slickmath.EPSILON) >= 0 then
            if apex.index == left.index or slickmath.direction(right.point, otherLeft.point, apex.point, slickmath.EPSILON) < 0 then
                left = otherLeft
                leftIndex = index
            else
                table.insert(self.funnel, right)
                apex = right
                left = right

                leftIndex = rightIndex

                index = rightIndex
            end
        end

        index = index + 1
    end

    table.insert(self.funnel, self.portals[#self.portals])
end

--- @private
--- @param mesh slick.navigation.mesh
--- @param startX number
--- @param startY number
--- @param goalX number
--- @param goalY number
--- @param nearest boolean
--- @param result number[]?
--- @return number[]?, slick.navigation.vertex[]?
function path:_find(mesh, startX, startY, goalX, goalY, nearest, result)
    self:_reset()

    self.behavior.start = mesh:getContainingTriangle(startX, startY)
    self.behavior.goal = mesh:getContainingTriangle(goalX, goalY)

    if not self.behavior.start then
        return nil
    end

    self.fScores[self.behavior.start] = 0
    self.gScores[self.behavior.start] = 0

    self.startVertex.point:init(startX, startY)
    self.goalVertex.point:init(goalX, goalY)

    local pending = true
    local current = self.behavior.start
    while pending and current and current ~= self.behavior.goal do
        if current == self.behavior.start then
            self.visitedEdges[self.startEdge] = true
        else
            assert(current ~= self.behavior.goal, "cannot visit goal")
            assert(self.graph[current], "current has no previous")

            local edge = mesh:getSharedTriangleEdge(self.graph[current], current)
            assert(edge, "missing edge between previous and current")

            self.visitedEdges[edge] = true
        end

        if not self.visitedTriangles[current] then
            table.insert(self.closed, current)
            self.visitedTriangles[current] = true
        end

        for _, neighbor in ipairs(self:_neighbors(mesh, current)) do
            local edge = mesh:getSharedTriangleEdge(current, neighbor)
            if not self.visitedEdges[edge] then
                local continuePathfinding = self.options.visit(current, neighbor, edge)
                if continuePathfinding == false then
                    pending = false
                    break
                end

                local distance = self.options.distance(current, neighbor, edge)
                local pendingGScore = (self.gScores[current] or math.huge) + distance
                if pendingGScore < (self.gScores[neighbor] or math.huge) then
                    local heuristic = self.options.heuristic(neighbor, goalX, goalY)

                    self.graph[neighbor] = current
                    self.gScores[neighbor] = pendingGScore
                    self.hScores[neighbor] = heuristic
                    self.fScores[neighbor] = pendingGScore + heuristic

                    table.insert(self.pending, neighbor)
                    table.sort(self.pending, self._sortFScoreFunc)
                end
            end
        end

        local continuePathfinding = self.options.yield()
        if continuePathfinding == false then
            pending = false
        end

        current = table.remove(self.pending)
    end

    local reachedGoal = current == self.behavior.goal and self.behavior.goal
    if not reachedGoal then
        if not nearest then
            return nil
        end

        local bestTriangle = nil
        local bestHScore = math.huge
        for _, triangle in ipairs(self.closed) do
            local hScore = self.hScores[triangle]
            if hScore and hScore < bestHScore then
                bestHScore = hScore
                bestTriangle = triangle
            end
        end

        if not bestTriangle then
            return nil
        end

        current = bestTriangle
    end

    slicktable.clear(self.path)
    while current do
        local next = self.graph[current]
        if next then
            table.insert(self.path, 1, mesh:getSharedTriangleEdge(current, next))
        end
        
        current = self.graph[current]
    end

    if #self.path == 0 then
        self.startVertex.point:init(startX, startY)
        self.goalVertex.point:init(goalX, goalY)

        table.insert(self.path, self.sharedStartGoalEdge)
    else
        self.startEdge.a.point:init(startX, startY)
        self.startEdge.b = self.path[1].a
        self.startEdge.min = math.min(self.startEdge.a.index, self.startEdge.b.index)
        self.startEdge.max = math.max(self.startEdge.a.index, self.startEdge.b.index)

        if self.startEdge.a.point:distance(self.startEdge.b.point) > slickmath.EPSILON then
            table.insert(self.path, 1, self.startEdge)
        end

        if reachedGoal then
            self.goalEdge.a = self.path[#self.path].b
            self.goalEdge.b.point:init(goalX, goalY)
            self.goalEdge.min = math.min(self.goalEdge.a.index, self.goalEdge.b.index)
            self.goalEdge.max = math.max(self.goalEdge.a.index, self.goalEdge.b.index)

            if self.goalEdge.a.point:distance(self.goalEdge.b.point) > slickmath.EPSILON then
                table.insert(self.path, self.goalEdge)
            end
        end
    end

    --- @type slick.navigation.vertex[]
    local path
    if self.options.optimize and #self.path > 1 then
        self:_funnel()
        path = self.funnel
    else
        slicktable.clear(self.result)
        if #self.path == 1 then
            local p = self.path[1]
            table.insert(self.result, p.a)
            table.insert(self.result, p.b)
        else
            table.insert(self.result, self.path[1].a)

            for i = 1, #self.path - 1 do
                local p1 = self.path[i]
                local p2 = self.path[i + 1]

                if p1.b.index == p2.a.index then
                    table.insert(self.result, p1.b)
                elseif p1.a.index == p2.b.index then
                    table.insert(self.result, p1.a)
                end
            end

            table.insert(self.result, self.path[#self.path].b)
        end
        path = self.result
    end

    result = result or {}
    slicktable.clear(result)
    for _, vertex in ipairs(path) do
        table.insert(result, vertex.point.x)
        table.insert(result, vertex.point.y)
    end

    return result, path
end

--- @param mesh slick.navigation.mesh
--- @param startX number
--- @param startY number
--- @param goalX number
--- @param goalY number
--- @return number[]?, slick.navigation.vertex[]?
function path:find(mesh, startX, startY, goalX, goalY)
    return self:_find(mesh, startX, startY, goalX, goalY, false)
end

--- @param mesh slick.navigation.mesh
--- @param startX number
--- @param startY number
--- @param goalX number
--- @param goalY number
--- @return number[]?, slick.navigation.vertex[]?
function path:nearest(mesh, startX, startY, goalX, goalY)
    return self:_find(mesh, startX, startY, goalX, goalY, true)
end

return path
