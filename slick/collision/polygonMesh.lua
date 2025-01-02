local polygon = require ("slick.collision.polygon")

--- @class slick.collision.polygonMesh
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

    for _, boundary in ipairs(self.boundaries) do
        local numPoints = #boundary / 2

        for i = 1, numPoints do
            local j = (i - 1) * 2 + 1
            local x, y = unpack(boundary, j, j + 1)

            table.insert(points, x, y)
            table.insert(edges, i, i % numPoints + 1)
        end
    end

    points, edges = triangulator:clean(points, edges, self.cleanupOptions)
    local triangles, _, polygons = triangulator:triangulate(points, edges, self.triangulationOptions)

    local p = polygons or triangles
    for _, vertices in ipairs(p) do
        local vertices = {}

        for _, vertex in ipairs(vertices) do
            local index = (vertex - 1) * 2 + 1
            local x, y = unpack(points, index, index + 1)

            table.insert(vertices, x)
            table.insert(vertices, y)
        end

        table.insert(self.polygons, polygon.new(self.entity, unpack(vertices)))
    end
end

return polygonMesh
