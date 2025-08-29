local quadTree = require "slick.collision.quadTree"
local quadTreeQuery = require "slick.collision.quadTreeQuery"
local point = require "slick.geometry.point"
local rectangle = require "slick.geometry.rectangle"
local segment = require "slick.geometry.segment"
local edge = require "slick.navigation.edge"
local triangle = require "slick.navigation.triangle"
local vertex = require "slick.navigation.vertex"
local search = require "slick.util.search"
local slickmath = require "slick.util.slickmath"

--- @class slick.navigation.mesh
--- @field vertices slick.navigation.vertex[]
--- @field edges slick.navigation.edge[]
--- @field bounds slick.geometry.rectangle
--- @field vertexNeighbors table<number, slick.navigation.edge[]>
--- @field triangles slick.navigation.triangle[]
--- @field inputPoints number[]
--- @field inputEdges number[]
--- @field inputExteriorEdges number[]
--- @field inputInteriorEdges number[]
--- @field inputUserdata any[]
--- @field vertexToTriangle table<number, slick.navigation.triangle[]>
--- @field triangleNeighbors table<number, slick.navigation.triangle[]>
--- @field sharedTriangleEdges table<number, table<number, slick.navigation.edge>>
--- @field edgeTriangles table<slick.navigation.edge, slick.navigation.triangle[]>
--- @field quadTree slick.collision.quadTree?
--- @field quadTreeQuery slick.collision.quadTreeQuery?
local mesh = {}
local metatable = { __index = mesh }


--- @param aTriangles slick.navigation.triangle[]
--- @param bTriangles slick.navigation.triangle[]
--- @param e slick.navigation.edge
--- @return slick.navigation.triangle?, slick.navigation.triangle?
local function _findSharedTriangle(aTriangles, bTriangles, e)
    for _, t1 in ipairs(aTriangles) do
        for _, t2 in ipairs(bTriangles) do
            if t1.index ~= t2.index then
                if t1.vertices[e.a.index] and t1.vertices[e.b.index] and t2.vertices[e.a.index] and t2.vertices[e.b.index] then
                    if t1.index ~= t2.index then
                        return t1, t2
                    end
                end
            end
        end
    end

    return nil, nil
end

--- @overload fun(points: number[], userdata: any[], edges: number[]): slick.navigation.mesh
--- @overload fun(points: number[], userdata: any[], exteriorEdges: number[], interiorEdges: number[]): slick.navigation.mesh
--- @overload fun(points: number[], userdata: any[], edges: number[], triangles: number[][]): slick.navigation.mesh
--- @return slick.navigation.mesh
function mesh.new(points, userdata, edges, z)
    local self = setmetatable({
        vertices = {},
        edges = {},
        vertexNeighbors = {},
        triangleNeighbors = {},
        triangles = {},
        inputPoints = {},
        inputEdges = {},
        inputUserdata = {},
        inputExteriorEdges = {},
        inputInteriorEdges = {},
        vertexToTriangle = {},
        sharedTriangleEdges = {},
        edgeTriangles = {},
        bounds = rectangle.new(points[1], points[2], points[1], points[2])
    }, metatable)

    for i = 1, #points, 2 do
        local n = (i - 1) / 2 + 1
        local vertex = vertex.new(point.new(points[i], points[i + 1]), userdata and userdata[n] or nil, n)

        table.insert(self.vertices, vertex)

        table.insert(self.inputPoints, points[i])
        table.insert(self.inputPoints, points[i + 1])

        self.inputUserdata[n] = userdata and userdata[n] or nil

        self.bounds:expand(points[i], points[i + 1])
    end

    for i = 1, #edges, 2 do
        table.insert(self.inputEdges, edges[i])
        table.insert(self.inputEdges, edges[i + 1])
        table.insert(self.inputExteriorEdges, edges[i])
        table.insert(self.inputExteriorEdges, edges[i + 1])
    end

    if z and type(z) == "table" and #z >= 1 and type(z[1]) == "table" and #z[1] == 3 then
        for _, t in ipairs(z) do
            local n = triangle.new(self.vertices[t[1]], self.vertices[t[2]], self.vertices[t[3]], #self.triangles + 1)

            for i = 1, #t do
                local j = (i % #t) + 1

                local s = t[i]
                local t = t[j]
                
                local e1 = edge.new(self.vertices[s], self.vertices[t])
                local e2 = edge.new(self.vertices[t], self.vertices[s])
                table.insert(self.edges, e1)

                local neighborsI = self.vertexNeighbors[s]
                if not neighborsI then
                    neighborsI = {}
                    self.vertexNeighbors[s] = neighborsI
                end

                local neighborsJ = self.vertexNeighbors[t]
                if not neighborsJ then
                    neighborsJ = {}
                    self.vertexNeighbors[t] = neighborsJ
                end

                do
                    local hasE = false
                    for _, neighbor in ipairs(neighborsI) do
                        if neighbor.min == e1.min and neighbor.max == e1.max then
                            hasE = true
                            break
                        end
                    end

                    if not hasE then
                        table.insert(neighborsI, e1)
                    end
                end

                do
                    local hasE = false
                    for _, neighbor in ipairs(neighborsJ) do
                        if neighbor.min == e2.min and neighbor.max == e2.max then
                            hasE = true
                            break
                        end
                    end

                    if not hasE then
                        table.insert(neighborsJ, e2)
                    end
                end

                local v = self.vertexToTriangle[s]
                if not v then
                    v = {}
                    self.vertexToTriangle[s] = v
                end

                table.insert(v, n)
            end

            table.insert(self.triangles, n)
        end

        table.sort(self.edges, edge.less)

        for _, e in ipairs(self.edges) do
            local aTriangles = self.vertexToTriangle[e.a.index]
            local bTriangles = self.vertexToTriangle[e.b.index]

            local a, b = _findSharedTriangle(aTriangles, bTriangles, e)
            if a and b then
                self.edgeTriangles[e] = { a, b }

                do
                    local x = self.sharedTriangleEdges[a.index]
                    if not x then
                        x = {}
                        self.sharedTriangleEdges[a.index] = x
                    end

                    x[b.index] = e
                end

                do
                    local x = self.sharedTriangleEdges[b.index]
                    if not x then
                        x = {}
                        self.sharedTriangleEdges[b.index] = x
                    end

                    x[a.index] = e
                end

                do
                    local neighbors = self.triangleNeighbors[a.index]
                    if neighbors == nil then
                        neighbors = {}
                        self.triangleNeighbors[a.index] = neighbors
                    end

                    local hasT = false
                    for _, neighbor in ipairs(neighbors) do
                        if neighbor.index == b.index then
                            hasT = true
                            break
                        end
                    end

                    if not hasT then
                        table.insert(neighbors, b)
                        assert(#neighbors <= 3)
                    end
                end

                do
                    local neighbors = self.triangleNeighbors[b.index]
                    if neighbors == nil then
                        neighbors = {}
                        self.triangleNeighbors[b.index] = neighbors
                    end

                    local hasT = false
                    for _, neighbor in ipairs(neighbors) do
                        if neighbor.index == a.index then
                            hasT = true
                            break
                        end
                    end

                    if not hasT then
                        table.insert(neighbors, a)
                        assert(#neighbors <= 3)
                    end
                end
            end
        end
    elseif z and type(z) == "table" and #z >= 2 and #z % 2 == 0 and type(z[1]) == "number" then
        for i = 1, #z, 2 do
            table.insert(self.inputEdges, z[i])
            table.insert(self.inputEdges, z[i + 1])
            table.insert(self.inputInteriorEdges, z[i])
            table.insert(self.inputInteriorEdges, z[i + 1])
        end
    end

    return self
end

--- @type slick.collision.quadTreeOptions
local _quadTreeOptions = {
    x = 0,
    y = 0,
    width = 0,
    height = 0
}

--- @private
function mesh:_buildQuadTree()
    _quadTreeOptions.x = self.bounds:left()
    _quadTreeOptions.y = self.bounds:top()
    _quadTreeOptions.width = self.bounds:width()
    _quadTreeOptions.height = self.bounds:height()

    self.quadTree = quadTree.new(_quadTreeOptions)
    self.quadTreeQuery = quadTreeQuery.new(self.quadTree)

    for _, triangle in ipairs(self.triangles) do
        self.quadTree:insert(triangle, triangle.bounds)
    end
end

local _getTrianglePoint = point.new()

--- @param x number
--- @param y number
--- @return slick.navigation.triangle | nil
function mesh:getContainingTriangle(x, y)
    if not self.quadTree then
        self:_buildQuadTree()
    end

    _getTrianglePoint:init(x, y)
    self.quadTreeQuery:perform(_getTrianglePoint, slickmath.EPSILON)

    for _, hit in ipairs(self.quadTreeQuery.results) do
        --- @cast hit slick.navigation.triangle

        local inside = true
        local currentSide
        for i = 1, #hit.triangle do
            local side = slickmath.direction(
                hit.triangle[i].point,
                hit.triangle[(i % #hit.triangle) + 1].point,
                _getTrianglePoint)

            -- Point is collinear with edge.
            -- We consider this inside.
            if side == 0 then
                break
            end

            if not currentSide then
                currentSide = side
            elseif currentSide ~= side then
                inside = false
                break
            end
        end

        if inside then
            return hit
        end
    end
    
    return nil
end

--- @param index number
--- @return slick.navigation.vertex
function mesh:getVertex(index)
    return self.vertices[index]
end

--- @param index number
--- @return slick.navigation.edge[]
function mesh:getTriangleNeighbors(index)
    return self.triangleNeighbors[index]
end

--- @param index number
--- @return slick.navigation.edge[]
function mesh:getVertexNeighbors(index)
    return self.vertexNeighbors[index]
end

local _insideSegment = segment.new()
local _triangleSegment = segment.new()
local _insideTriangleSegment = segment.new()

--- @param a slick.navigation.vertex
--- @param b slick.navigation.vertex
--- @return boolean, number?, number?
function mesh:cross(a, b)
    if not self.quadTree then
        self:_buildQuadTree()
    end

    _insideSegment:init(a.point, b.point)
    self.quadTreeQuery:perform(_insideSegment)

    local hasIntersectedTriangle = false
    local bestDistance = math.huge
    local bestX, bestY
    for _, hit in ipairs(self.quadTreeQuery.results) do
        --- @cast hit slick.navigation.triangle

        local intersectedTriangle = false
        for i, vertex in ipairs(hit.triangle) do
            local otherVertex = hit.triangle[(i % #hit.triangle) + 1]

            _triangleSegment:init(vertex.point, otherVertex.point)
            _insideTriangleSegment:init(vertex.point, otherVertex.point)
            _insideTriangleSegment.a:init(vertex.point.x, vertex.point.y)
            _insideTriangleSegment.b:init(otherVertex.point.x, otherVertex.point.y)

            local i, x, y, u, v = slickmath.intersection(vertex.point, otherVertex.point, a.point, b.point, slickmath.EPSILON)
            if i and u and v then
                intersectedTriangle = true

                if not self:isSharedEdge(vertex.index, otherVertex.index) then
                    local distance = (x - a.point.x) ^ 2 + (x - a.point.y) ^ 2
                    if distance < bestDistance then
                        bestDistance = distance
                        bestX, bestY = x, y
                    end
                end
            end
        end

        hasIntersectedTriangle = hasIntersectedTriangle or intersectedTriangle
    end

    return hasIntersectedTriangle, bestX, bestY
end

local _a = vertex.new(point.new(0, 0), nil, 1)
local _b = vertex.new(point.new(0, 0), nil, 2)
local _edge = edge.new(_a, _b)

--- @param a number
--- @param b number
--- @return slick.navigation.edge
function mesh:getEdge(a, b)
    _edge.a = self.vertices[a]
    _edge.b = self.vertices[b]
    _edge.min = math.min(a, b)
    _edge.max = math.max(a, b)

    local index = search.first(self.edges, _edge, edge.compare)
    return self.edges[index]
end

--- @param a slick.navigation.triangle
--- @param b slick.navigation.triangle
--- @return slick.navigation.edge
function mesh:getSharedTriangleEdge(a, b)
    local t = self.sharedTriangleEdges[a.index]
    local e = t and t[b.index]

    return e
end

--- @param a number
--- @param b number
function mesh:isSharedEdge(a, b)
    local edge = self:getEdge(a, b)
    local triangles = self.edgeTriangles[edge]
    return triangles ~= nil and #triangles == 2
end

--- @param a number
--- @param b number
--- @return slick.navigation.triangle ...
function mesh:getEdgeTriangles(a, b)
    local edge = self:getEdge(a, b)
    local triangles = self.edgeTriangles[edge]
    if not triangles then
        return
    end

    return unpack(triangles)
end

return mesh
