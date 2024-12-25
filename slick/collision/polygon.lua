local point = require("slick.geometry.point")
local transform = require("slick.geometry.transform")
local slickmath = require("slick.util.slickmath")

--- @class slick.collision.polygon
--- @field vertexCount number
--- @field normalCount number
--- @field center slick.geometry.point
--- @field vertices slick.geometry.point[]
--- @field private preTransformedVertices slick.geometry.point[]
--- @field normals slick.geometry.point[]
--- @field private preTransformedNormals slick.geometry.point[]
local polygon = {}
local metatable = { __index = polygon }

--- @param x1 number
--- @param y1 number
--- @param ... number
--- @return slick.collision.polygon
function polygon.new(x1, y1, ...)
    local result = setmetatable({
        vertexCount = 0,
        normalCount = 0,
        center = point.new(),
        vertices = {},
        preTransformedVertices = {},
        normals = {},
        preTransformedNormals = {}
    }, metatable)

    result:init(x1, y1, ...)

    return result
end

--- @param x1 number
--- @param y1 number
--- @param ... number
function polygon:init(x1, y1, ...)
    self.vertexCount = 0
    self.normalCount = 0

    self:_addPoint(x1, y1, ...)
    self:_buildNormals()
    self:transform(transform.IDENTITY)

    assert(self.vertexCount >= 3, "polygon must have at least 3 points")
    assert(self.vertexCount == self.normalCount, "polygon must have as many normals as vertices")
end

--- @private
--- @param x1 number?
--- @param y1 number?
--- @param ... number?
function polygon:_addPoint(x1, y1, ...)
    if not (x1 and y1) then
        return
    end

    self.vertexCount = self.vertexCount + 1
    local p = self.preTransformedVertices[self.vertexCount]
    if not p then
        p = point.new()
        table.insert(self.preTransformedVertices, p)
    end
    p:init(x1, y1)

    self:_addPoint(...)
end

--- @private
--- @param i number
--- @param p1 slick.geometry.point
--- @param p2 slick.geometry.point
function polygon:_addNormal(i, p1, p2)
    self.normalCount = self.normalCount + 1

    local normal = self.preTransformedNormals[i]
    if not normal then
        normal = point.new()
        self.preTransformedNormals[i] = normal
    end

    p1:direction(p2, normal)
    normal:normalize(normal)

    return normal
end

function polygon:_buildNormals()
    local direction = slickmath.direction(self.preTransformedVertices[1], self.preTransformedVertices[2], self.preTransformedVertices[3])
    assert(direction ~= 0, "polygon is degenerate")

    for i = 1, self.vertexCount do
        local j = i % self.vertexCount + 1

        local p1 = self.preTransformedVertices[i]
        local p2 = self.preTransformedVertices[j]

        local n = self:_addNormal(i, p1, p2)
        if direction < 0 then
            n:left(n)
        else
            n:right(n)
        end
    end
end

--- @param transform slick.geometry.transform
function polygon:transform(transform)
    self.center:init(0, 0)
    for i = 1, self.vertexCount do
        local preTransformedVertex = self.preTransformedVertices[i]
        local postTransformedVertex = self.vertices[i]
        if not postTransformedVertex then
            postTransformedVertex = point.new()
            self.vertices[i] = postTransformedVertex
        end
        postTransformedVertex:init(transform:transformPoint(preTransformedVertex.x, preTransformedVertex.y))

        postTransformedVertex:add(self.center, self.center)
    end
    self.center:divideScalar(self.vertexCount, self.center)

    for i = 1, self.normalCount do
        local preTransformedNormal = self.preTransformedNormals[i]
        local postTransformedNormal = self.normals[i]
        if not postTransformedNormal then
            postTransformedNormal = point.new()
            self.normals[i] = postTransformedNormal
        end
        postTransformedNormal:init(transform:transformNormal(preTransformedNormal.x, preTransformedNormal.y))
        postTransformedNormal:normalize(postTransformedNormal)
    end
end

--- @param query slick.collision.shapeCollisionResolutionQuery
function polygon:getAxes(query)
    query:getAxes()
end

--- @param query slick.collision.shapeCollisionResolutionQuery
--- @param axis slick.geometry.point
--- @param interval slick.collision.interval
function polygon:project(query, axis, interval)
    query:project(axis, interval)
end

return polygon