local point = require "slick.geometry.point"
local vertex = require "slick.navigation.vertex"
local slicktable = require "slick.util.slicktable"
local slickmath  = require "slick.util.slickmath"

--- @class slick.navigation.pathOptions
--- @field optimize boolean?
--- @field neighbor nil | fun(fromX: number, fromY: number, fromUserdata: any, toX: number, toY: number, toUserdata: any): boolean
--- @field neighbors nil | fun(mesh: slick.navigation.mesh, vertex: slick.navigation.vertex): slick.navigation.edge[] | nil
--- @field distance nil | fun(fromX: number, fromY: number, fromUserdata: any, toX: number, toY: number, toUserdata: any): number
--- @field heuristic nil | fun(x: number, y: number, userdata: any, goalX: number, goalY: number): number
--- @field yield fun() | nil
local defaultPathOptions = {
    optimize = true
}

--- @generic F
--- @generic T
--- @param fromX number
--- @param fromY number
--- @param fromUserdata F
--- @param toX number
--- @param toY number
--- @param toUserdata T
--- @return boolean
function defaultPathOptions.neighbor(fromX, fromY, fromUserdata, toX, toY, toUserdata)
    return true
end

--- @param mesh slick.navigation.mesh
--- @param vertex slick.navigation.vertex
--- @return slick.navigation.edge[] | nil
function defaultPathOptions.neighbors(mesh, vertex)
    return mesh:getVertexNeighbors(vertex.index)
end

--- @generic F
--- @generic T
--- @param fromX number
--- @param fromY number
--- @param fromUserdata F
--- @param toX number
--- @param toY number
--- @param toUserdata T
--- @return number
function defaultPathOptions.distance(fromX, fromY, fromUserdata, toX, toY, toUserdata)
    return math.sqrt((fromX - toX) ^ 2 + (fromY - toY) ^ 2)
end

--- @generic U
--- @param x number
--- @param y number
--- @param userdata U
--- @param goalX number
--- @param goalY number
--- @return number
function defaultPathOptions.heuristic(x, y, userdata, goalX, goalY)
    return math.sqrt((x - goalX) ^ 2 + (y - goalY) ^ 2)
end

function defaultPathOptions.yield()
    -- Nothing.
end

--- @class slick.navigation.impl.pathBehavior
--- @field start slick.navigation.vertex
--- @field goal slick.navigation.vertex
--- @field goalTriangle slick.navigation.triangle
local internalPathBehavior = {}

--- @class slick.navigation.path
--- @field private options slick.navigation.pathOptions
--- @field private behavior slick.navigation.impl.pathBehavior
--- @field private fScores table<slick.navigation.vertex, number>
--- @field private gScores table<slick.navigation.vertex, number>
--- @field private hScores table<slick.navigation.vertex, number>
--- @field private visited table<slick.navigation.vertex, true>
--- @field private pending slick.navigation.vertex[]
--- @field private closed slick.navigation.vertex[]
--- @field private neighbors slick.navigation.vertex[]
--- @field private graph table<slick.navigation.vertex, slick.navigation.vertex>
--- @field private result slick.navigation.vertex[]
--- @field private portals slick.navigation.vertex[]
--- @field private funnel slick.navigation.vertex[]
--- @field private _sortFScoreFunc fun(a: slick.navigation.vertex, b: slick.navigation.vertex): boolean
--- @field private _sortHScoreFunc fun(a: slick.navigation.vertex, b: slick.navigation.vertex): boolean
local path = {}
local metatable = { __index = path }

--- @param options slick.navigation.pathOptions
function path.new(options)
    local self = setmetatable({
        options = {
            optimize = options.optimize == nil and defaultPathOptions.optimize or not not options.optimize,
            neighbor = options.neighbor or defaultPathOptions.neighbor,
            neighbors = options.neighbors or defaultPathOptions.neighbors,
            distance = options.distance or defaultPathOptions.distance,
            heuristic = options.heuristic or defaultPathOptions.heuristic,
            yield = options.yield or defaultPathOptions.yield,
        },

        behavior = {
            start = vertex.new(point.new(0, 0), nil, -1),
            goal = vertex.new(point.new(0, 0), nil, -2)
        },

        fScores = {},
        gScores = {},
        hScores = {},
        visited = {},
        pending = {},
        closed = {},
        neighbors = {},
        graph = {},
        result = {},
        portals = {},
        funnel = {}
    }, metatable)

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

local _neighborIndices = {}

--- @private
--- @param mesh slick.navigation.mesh
--- @param vertex slick.navigation.vertex
--- @return slick.navigation.vertex[]
function path:_neighbors(mesh, vertex)
    slicktable.clear(self.neighbors)

    if vertex == self.behavior.start then
        local triangle = mesh:getContainingTriangle(vertex.point.x, vertex.point.y)

        if triangle then
            for _, vertex in ipairs(triangle.triangle) do
                table.insert(self.neighbors, vertex)
            end
        end

        if triangle == self.behavior.goalTriangle then
            table.insert(self.neighbors, self.behavior.goal)
        end

        return self.neighbors
    end

    --- @type slick.navigation.vertex[]
    slicktable.clear(_neighborIndices)

    local neighbors = self.options.neighbors(mesh, vertex)
    if neighbors then
        for _, neighbor in ipairs(neighbors) do
            if self.options.neighbor(neighbor.a.point.x, neighbor.a.point.y, neighbor.a.userdata, neighbor.b.point.x, neighbor.b.point.y, neighbor.b.userdata) then
                _neighborIndices[neighbor.b.index] = true
                table.insert(self.neighbors, neighbor.b)
            end
        end
    end

    local hasGoal
    if self.behavior.goalTriangle then
        hasGoal = true

        for _, v in ipairs(self.behavior.goalTriangle.triangle) do
            if not (_neighborIndices[v.index] or v.index == vertex.index) then
                hasGoal = false
                break
            end
        end
    else
        hasGoal = false
    end

    if hasGoal then
        table.insert(self.neighbors, self.behavior.goal)
    end

    return self.neighbors
end

--- @private
function path:_reset()
    slicktable.clear(self.fScores)
    slicktable.clear(self.gScores)
    slicktable.clear(self.hScores)
    slicktable.clear(self.visited)
    slicktable.clear(self.pending)
    slicktable.clear(self.graph)

    self.path = nil
end

--- @private
function path:_funnel()
    slicktable.clear(self.funnel)
    -- slicktable.clear(self.portals)

    -- table.insert(self.portals, self.result[1])
    -- table.insert(self.portals, self.result[1])
    -- for i = 2, #self.result do
    --     table.insert(self.portals, self.result[i - 1])
    --     table.insert(self.portals, self.result[i])
    -- end
    -- table.insert(self.portals, self.result[#self.result])
    -- table.insert(self.portals, self.result[#self.result])

    local apex, left, right = self.result[1], self.result[1], self.result[2]
    local leftIndex, rightIndex = 1, 2

    table.insert(self.funnel, apex)

    local index = 2
    while index < #self.result do
        local otherLeft = self.result[index]
        local otherRight = self.result[index + 1]

        local nextIndex = index
        local skip = false

        if slickmath.direction(apex.point, right.point, otherRight.point, slickmath.EPSILON) >= 0 then
            if apex.index == right.index or slickmath.direction(apex.point, left.point, otherRight.point, slickmath.EPSILON) < 0 then
                right = otherRight
                rightIndex = index
            else
                table.insert(self.funnel, left)
                apex = left
                rightIndex = leftIndex
                nextIndex = leftIndex

                left = apex
                right = apex
                
                skip = true
            end
        end

        if not skip and slickmath.direction(apex.point, left.point, otherLeft.point, slickmath.EPSILON) <= 0 then
            if apex.index == left.index or slickmath.direction(apex.point, right.point, otherLeft.point, slickmath.e) > 0 then
                left = otherLeft
                leftIndex = index
            else
                table.insert(self.funnel, right)
                apex = right
                leftIndex = rightIndex
                nextIndex = rightIndex

                left = apex
                right = apex
            end
        end

        index = nextIndex + 1
    end

    table.insert(self.funnel, self.result[#self.result])
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

    self.behavior.start.point:init(startX, startY)
    self.behavior.goal.point:init(goalX, goalY)
    self.behavior.goalTriangle = mesh:getContainingTriangle(goalX, goalY)

    self.fScores[self.behavior.start] = 0
    self.gScores[self.behavior.start] = 0

    local current = self.behavior.start
    while current and current ~= self.behavior.goal do
        self.visited[current] = true
        table.insert(self.closed, current)

        for _, neighbor in ipairs(self:_neighbors(mesh, current)) do
            if not self.visited[neighbor] then
                local distance = self.options.distance(current.point.x, current.point.y, current.userdata, neighbor.point.x, neighbor.point.y, neighbor.userdata)
                local pendingGScore = (self.gScores[current] or math.huge) + distance
                if pendingGScore < (self.gScores[neighbor] or math.huge) then
                    local heuristic = self.options.heuristic(neighbor.point.x, neighbor.point.y, neighbor.userdata, self.behavior.goal.point.x, self.behavior.goal.point.y)

                    self.graph[neighbor] = current
                    self.gScores[neighbor] = pendingGScore
                    self.hScores[neighbor] = heuristic
                    self.fScores[neighbor] = pendingGScore + heuristic

                    table.insert(self.pending, neighbor)
                    table.sort(self.pending, self._sortFScoreFunc)
                end
            end
        end

        self.options.yield()
        current = table.remove(self.pending)
    end

    if current ~= self.behavior.goal then
        if not nearest then
            return nil
        end

        local bestVertex = nil
        local bestHScore = math.huge
        for _, vertex in ipairs(self.closed) do
            local hScore = self.hScores[vertex]
            if hScore and hScore < bestHScore then
                bestHScore = hScore
                bestVertex = vertex
            end
        end

        if not bestVertex then
            return nil
        end

        current = bestVertex
    end

    slicktable.clear(self.result)
    while current do
        table.insert(self.result, 1, current)
        current = self.graph[current]
    end

    local path = self.result
    if self.options.optimize then
        self:_funnel()
        path = self.funnel
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
--- @return number[] | nil
function path:find(mesh, startX, startY, goalX, goalY)
    return self:_find(mesh, startX, startY, goalX, goalY, false)
end

--- @param mesh slick.navigation.mesh
--- @param startX number
--- @param startY number
--- @param goalX number
--- @param goalY number
--- @return number[] | nil
function path:nearest(mesh, startX, startY, goalX, goalY)
    return self:_find(mesh, startX, startY, goalX, goalY, true)
end

return path
