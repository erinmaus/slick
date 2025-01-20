local polygon = require ("slick.collision.polygon")

--- @class slick.collision.polygonMesh
--- @field tag any
--- @field entity slick.entity
--- @field boundaries number[][]
--- @field polygons slick.collision.polygon[]
--- @field cleanupOptions slick.geometry.triangulation.delaunayCleanupOptions
--- @field triangulationOptions slick.geometry.triangulation.delaunayTriangulationOptions
local polygonMesh = {}
local metatable = { __index = polygonMesh }

--- @param entity slick.entity
--- @param ... number[]
--- @return slick.collision.polygonMesh
function polygonMesh.new(entity, ...)
    local result = setmetatable({
        entity = entity,
        boundaries = { ... },
        polygons = {},
        cleanupOptions = {},
        triangulationOptions = {
            refine = true,
            interior = true,
            exterior = false,
            polygonization = true
        }
    }, metatable)

    return result
end

--- @param triangulator slick.geometry.triangulation.delaunay
function polygonMesh:build(triangulator)
    local points = {}
    local edges = {}

    local totalPoints = 0
    for _, boundary in ipairs(self.boundaries) do
        local numPoints = #boundary / 2

        for i = 1, numPoints do
            local j = (i - 1) * 2 + 1
            local x, y = unpack(boundary, j, j + 1)

            table.insert(points, x)
            table.insert(points, y)
            table.insert(edges, i + totalPoints)
            table.insert(edges, i % numPoints + 1 + totalPoints)
        end

        totalPoints = totalPoints + numPoints
    end

    points, edges = triangulator:clean(points, edges, self.cleanupOptions)
    local triangles, _, polygons = triangulator:triangulate(points, edges, self.triangulationOptions)

    local p = polygons or triangles
    for _, vertices in ipairs(p) do
        local outputVertices = {}

        for _, vertex in ipairs(vertices) do
            local index = (vertex - 1) * 2 + 1
            local x, y = unpack(points, index, index + 1)

            table.insert(outputVertices, x)
            table.insert(outputVertices, y)
        end

        local instantiatedPolygon = polygon.new(self.entity, unpack(outputVertices))
        instantiatedPolygon.tag = self.tag

        table.insert(self.polygons, instantiatedPolygon)
    end
end

return polygonMesh
