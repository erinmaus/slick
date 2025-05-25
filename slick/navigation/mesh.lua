local quadTree = require "slick.collision.quadTree"
local quadTreeQuery = require "slick.collision.quadTreeQuery"
local point = require "slick.geometry.point"
local rectangle = require "slick.geometry.rectangle"
local edge = require "slick.navigation.edge"
local vertex = require "slick.navigation.vertex"
local search = require "slick.util.search"
local slickmath = require "slick.util.slickmath"

--- @class slick.navigation.mesh
--- @field vertices slick.navigation.vertex[]
--- @field edges slick.navigation.edge[]
--- @field bounds slick.geometry.rectangle
--- @field neighbors table<number, slick.navigation.edge[]>
--- @field triangles number[][]
--- @field inputPoints number[]
--- @field inputEdges number[]
--- @field inputUserdata any[]
--- @field quadTree slick.collision.quadTree?
--- @field quadTreeQuery slick.collision.quadTreeQuery?
local mesh = {}
local metatable = { __index = mesh }

--- @param points number[]
--- @param userdata any[]
--- @param edges number[]
--- @param triangles number[][]?
--- @return slick.navigation.mesh
function mesh.new(points, userdata, edges, triangles)
    local self = setmetatable({
        vertices = {},
        edges = {},
        neighbors = {},
        triangles = {},
        inputPoints = {},
        inputEdges = {},
        inputUserdata = {},
        bounds = rectangle.new(points[1], points[2], points[1], points[2])
    }, metatable)

    for i = 1, #points, 2 do
        local n = (i - 1) / 2 + 1
        local vertex = vertex.new(point.new(points[i], points[i + 1]), userdata and userdata[n] or nil, n)

        table.insert(self.vertices, vertex)

        table.insert(self.inputPoints, points[i])
        table.insert(self.inputPoints, points[i + 1])

        table.insert(self.inputUserdata, userdata and userdata[n] or nil)

        self.bounds:expand(points[i], points[i + 1])
    end

    for i = 1, #edges do
        table.insert(self.inputEdges, edges[i])
    end

    if triangles then
        for _, triangle in ipairs(triangles) do
            --- @cast triangle number[]

            for i = 1, #triangle do
                local j = (i % #triangle) + 1
                
                local e = edge.new(self.vertices[i], self.vertices[j])
                table.insert(self.edges, e)

                local neighborsI = self.neighbors[i]
                if not neighborsI then
                    neighborsI = {}
                    self.neighbors[i] = neighborsI
                end

                local neighborsJ = self.neighbors[j]
                if not neighborsJ then
                    neighborsJ = {}
                    self.neighbors[j] = neighborsJ
                end

                table.insert(neighborsI, e)
                table.insert(neighborsJ, e)

                table.insert(self.inputEdges, i)
                table.insert(self.inputEdges, j)
            end

            table.insert(self.triangles, { unpack(triangle) })
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

local _quadTreeTriangleBounds = rectangle.new()

--- @private
function mesh:_buildQuadTree()
    _quadTreeOptions.x = self.bounds:left()
    _quadTreeOptions.y = self.bounds:top()
    _quadTreeOptions.width = self.bounds:width()
    _quadTreeOptions.height = self.bounds:height()

    self.quadTree = quadTree.new(_quadTreeOptions)
    self.quadTreeQuery = quadTreeQuery.new(self.quadTree)

    for _, triangle in ipairs(self.triangles) do
        local v = self.vertices[triangle[1]]
        _quadTreeTriangleBounds:init(v.point.x, v.point.y, v.point.x, v.point.y)

        for i = 2, #triangle do
            local otherV = self.vertices[triangle[i]]
            _quadTreeTriangleBounds:expand(otherV.point.x, otherV.point.y)
        end

        self.quadTree:insert(triangle, _quadTreeTriangleBounds)
    end
end

local _getTrianglePoint = point.new()

--- @param x number
--- @param y number
--- @return number[]?
function mesh:getContainingTriangle(x, y)
    if not self.quadTree then
        self:_buildQuadTree()
    end

    _getTrianglePoint:init(x, y)
    self.quadTreeQuery:perform(_getTrianglePoint, slickmath.EPSILON)

    for _, hit in ipairs(self.quadTreeQuery.results) do
        local inside = true
        local currentSide
        for i = 1, #hit do
            local side = slickmath.direction(
                self.vertices[hit[i]].point,
                self.vertices[hit[i % #hit + 1]].point,
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
function mesh:getNeighbors(index)
    return self.neighbors[index]
end

return mesh
