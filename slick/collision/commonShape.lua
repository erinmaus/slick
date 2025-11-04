local point = require("slick.geometry.point")
local rectangle = require("slick.geometry.rectangle")
local segment = require("slick.geometry.segment")
local slickmath = require("slick.util.slickmath")
local slicktable = require("slick.util.slicktable")

--- @class slick.collision.commonShape
--- @field tag any
--- @field entity slick.entity | slick.cache | nil
--- @field vertexCount number
--- @field normalCount number
--- @field center slick.geometry.point
--- @field vertices slick.geometry.point[]
--- @field bounds slick.geometry.rectangle
--- @field private preTransformedVertices slick.geometry.point[]
--- @field normals slick.geometry.point[]
--- @field private preTransformedNormals slick.geometry.point[]
local commonShape = {}
local metatable = { __index = commonShape }

--- @param e slick.entity | slick.cache | nil
--- @return slick.collision.commonShape
function commonShape.new(e)
    return setmetatable({
        entity = e,
        vertexCount = 0,
        normalCount = 0,
        center = point.new(),
        bounds = rectangle.new(),
        vertices = {},
        preTransformedVertices = {},
        normals = {},
        preTransformedNormals = {}
    }, metatable)
end

function commonShape:init()
    self.vertexCount = 0
    self.normalCount = 0
end

function commonShape:makeClockwise()
    -- Line segments don't have a winding.
    -- And points nor empty polygons do either.
    if self.vertexCount < 3 then
        return
    end

    local winding
    for i = 1, self.vertexCount do
        local j = slickmath.wrap(i, 1, self.vertexCount)
        local k = slickmath.wrap(j, 1, self.vertexCount)

        local side = slickmath.direction(
            self.preTransformedVertices[i],
            self.preTransformedVertices[j],
            self.preTransformedVertices[k])
        
        if side ~= 0 then
            winding = side
            break
        end
    end

    if not winding then
        return
    end

    if winding <= 0 then
        return
    end

    local i = self.vertexCount
    local j = 1

    while i > j do
        self.preTransformedVertices[i], self.preTransformedVertices[j] = self.preTransformedVertices[j], self.preTransformedVertices[i]

        i = i - 1
        j = j + 1
    end
end

--- @protected
--- @param x1 number?
--- @param y1 number?
--- @param ... number?
function commonShape:addPoints(x1, y1, ...)
    if not (x1 and y1) then
        self:makeClockwise()
        return
    end

    self.vertexCount = self.vertexCount + 1
    local p = self.preTransformedVertices[self.vertexCount]
    if not p then
        p = point.new()
        table.insert(self.preTransformedVertices, p)
    end
    p:init(x1, y1)

    self:addPoints(...)
end

--- @protected
--- @param x number
--- @param y number
function commonShape:addNormal(x, y)
    assert(not (x == 0 and y == 0))

    self.normalCount = self.normalCount + 1

    local normal = self.preTransformedNormals[self.normalCount]
    if not normal then
        normal = point.new()
        self.preTransformedNormals[self.normalCount] = normal
    end
    
    normal:init(x, y)
    normal:normalize(normal)

    return normal
end

--- @param p slick.geometry.point
--- @return boolean
function commonShape:inside(p)
    local inside = false
    local currentSide = 0
    for i = 1, self.vertexCount do
        local side = slickmath.direction(self.vertices[i], self.vertices[i % self.vertexCount + 1], p)

        -- Point is collinear with edge.
        -- We consider this inside.
        if side == 0 then
            return true
        end

        if side ~= currentSide then
            currentSide = side
            inside = not inside
        end
    end

    return inside
end

local _cachedNormal = point.new()
function commonShape:buildNormals()
    local direction = slickmath.direction(self.preTransformedVertices[1], self.preTransformedVertices[2], self.preTransformedVertices[3])
    assert(direction ~= 0, "polygon is degenerate")
    if direction < 0 then
        slicktable.reverse(self.preTransformedVertices)
    end


    for i = 1, self.vertexCount do
        local j = i % self.vertexCount + 1

        local p1 = self.preTransformedVertices[i]
        local p2 = self.preTransformedVertices[j]

        p1:direction(p2, _cachedNormal)

        local n = self:addNormal(_cachedNormal.x, _cachedNormal.y)
        n:right(n)
    end
end

--- @param transform slick.geometry.transform
function commonShape:transform(transform)
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

    self.bounds:init(self.vertices[1].x, self.vertices[1].y, self.vertices[1].x, self.vertices[1].y)
    for i = 2, self.vertexCount do
        self.bounds:expand(self.vertices[i].x, self.vertices[i].y)
    end

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
function commonShape:getAxes(query)
    query:getAxes()
end

--- @param query slick.collision.shapeCollisionResolutionQuery
--- @param axis slick.geometry.point
--- @param interval slick.collision.interval
--- @param offset slick.geometry.point?
function commonShape:project(query, axis, interval, offset)
    query:project(axis, interval, offset)
end

local _cachedDistanceSegment = segment.new()

--- @param p slick.geometry.point
function commonShape:distance(p)
    if self:inside(p) then
        return 0
    end

    local minDistance = math.huge

    for i = 1, self.vertexCount do
        local j = i % self.vertexCount + 1
        
        _cachedDistanceSegment:init(self.vertices[i], self.vertices[j])
        local distanceSquared = _cachedDistanceSegment:distanceSquared(p)
        if distanceSquared < minDistance then
            minDistance = distanceSquared
        end
    end
    
    if minDistance < math.huge then
        return math.sqrt(minDistance)
    end
    
    return math.huge
end

local _cachedRaycastHit = point.new()
local _cachedRaycastSegment = segment.new()

--- @param r slick.geometry.ray
--- @param normal slick.geometry.point?
--- @return boolean, number?, number?
function commonShape:raycast(r, normal)
    local bestDistance = math.huge
    local hit, x, y

    for i = 1, self.vertexCount do
        local j = i % self.vertexCount + 1

        local a = self.vertices[i]
        local b = self.vertices[j]

        _cachedRaycastSegment:init(a, b)
        local h, hx, hy = r:hitSegment(_cachedRaycastSegment)
        if h and hx and hy then
            hit = true

            _cachedRaycastHit:init(hx, hy)
            local distance = _cachedRaycastHit:distanceSquared(r.origin)
            if distance < bestDistance then
                bestDistance = distance
                x, y = hx, hy

                if normal then
                    a:direction(b, normal)
                end
            end
        end
    end

    if normal and hit then
        normal:normalize(normal)
        normal:left(normal)
    end

    return hit or false, x, y
end

return commonShape
