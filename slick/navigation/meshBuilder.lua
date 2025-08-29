local cache = require "slick.cache"
local polygon = require "slick.collision.polygon"
local shapeGroup = require "slick.collision.shapeGroup"
local clipper = require "slick.geometry.clipper"
local enum = require "slick.enum"
local mesh = require "slick.navigation.mesh"
local tag = require "slick.tag"
local util = require "slick.util"
local slicktable = require "slick.util.slicktable"
local slickmath = require "slick.util.slickmath"
local lineSegment = require "slick.collision.lineSegment"

--- @alias slick.navigation.navMeshBuilder.combineMode "union" | "difference"

--- @alias slick.navigation.navMeshBuilder.layerSettings {
---     key: any,
---     combineMode: slick.navigation.navMeshBuilder.combineMode,
---     mesh: slick.navigation.mesh?,
--- }

--- @class slick.navigation.navMeshBuilder
--- @field cache slick.cache
--- @field clipper slick.geometry.clipper
--- @field layers table<any, slick.navigation.navMeshBuilder.layerSettings>
--- @field layerMeshes table<any, slick.navigation.mesh[]>
--- @field layerCombineMode slick.navigation.navMeshBuilder.combineMode
--- @field private cachedPolygon slick.collision.polygon
--- @field private pointsCache number[]
--- @field private edgesCache number[]
--- @field private userdataCache number[]
--- @field private inputTriangles number[][]
--- @field private trianglesCache number[][]
local navMeshBuilder = {}
local metatable = { __index = navMeshBuilder }

--- @type slick.geometry.triangulation.delaunayTriangulationOptions
local triangulationOptions = {
    refine = true,
    interior = true,
    exterior = false,
    polygonization = false
}

local function _getKey(t)
    if util.is(t, tag) then
        return t.value
    elseif util.is(t, enum) then
        return t
    else
        error("expected tag to be instance of slick.tag or slick.enum")
    end
end

--- @type slick.options
local defaultOptions = {
    epsilon = slickmath.EPSILON,
    debug = false
}

--- @param options slick.options?
--- @return slick.navigation.navMeshBuilder
function navMeshBuilder.new(options)
    local c = cache.new(options or defaultOptions)
    return setmetatable({
        cache = c,
        clipper = clipper.new(c.triangulator),
        layers = {},
        layerMeshes = {},
        layerSettings = {},
        cachedPolygon = polygon.new(c),
        pointsCache = {},
        edgesCache = {},
        userdataCache = {},
    }, metatable)
end

--- @param t slick.tag | slick.enum
--- @param combineMode slick.navigation.navMeshBuilder.combineMode?
function navMeshBuilder:addLayer(t, combineMode)
    local key = _getKey(t)

    for _, layer in ipairs(self.layers) do
        if layer.key == key then
            error("layer already exists")
        end
    end

    if combineMode == nil then
        if #self.layers == 0 then
            combineMode = "union"
        else
            combineMode = "difference"
        end
    end
    
    table.insert(self.layers, {
        key = key,
        combineMode = combineMode,
        points = {},
        userdata = {},
        edges = {}
    })

    self.layerMeshes[key] = {}
end

--- @param t slick.tag | slick.enum
--- @param m slick.navigation.mesh
function navMeshBuilder:addMesh(t, m)
    local key = _getKey(t)

    local meshes = self.layerMeshes[key]
    if not meshes then
        error("layer with given slick.tag or slick.enum does not exist")
    end

    table.insert(meshes, m)
end

--- @param shape slick.collision.shape
--- @param points number[]
--- @param edges number[]
--- @param userdata any[]
local function _shapeToPointEdges(shape, points, edges, userdata, userdataValue)
    slicktable.clear(points)
    slicktable.clear(edges)
    slicktable.clear(userdata)

    if util.is(shape, lineSegment) then
        --- @cast shape slick.collision.lineSegment
        for i = 1, #shape.vertices do
            local v = shape.vertices[i]

            table.insert(points, v.x)
            table.insert(points, v.y)

            if i < #shape.vertices then
                table.insert(edges, i)
                table.insert(edges, i + 1)
            end

            if userdataValue ~= nil then
                table.insert(userdata, userdataValue)
            end
        end
    else

        --- @cast shape slick.collision.commonShape
        for i, v in ipairs(shape.vertices) do
            table.insert(points, v.x)
            table.insert(points, v.y)

            local j = (i % #shape.vertices) + 1
            table.insert(edges, i)
            table.insert(edges, j)

            if userdataValue ~= nil then
                table.insert(userdata, userdataValue)
            end
        end
    end
end

local _previousShapePoints, _previousShapeEdges, _previousShapeUserdata = {}, {}, {}
local _currentShapePoints, _currentShapeEdges, _currentShapeUserdata = {}, {}, {}
local _nextShapePoints, _nextShapeEdges, _nextShapeUserdata = {}, {}, {}

--- @param t slick.tag | slick.enum
--- @param shape slick.collision.shapeDefinition
--- @param userdata any
function navMeshBuilder:addShape(t, shape, userdata)
    local shapes = shapeGroup.new(self.cache, nil, shape)
    shapes:attach()

    _shapeToPointEdges(shapes.shapes[1], _previousShapePoints, _previousShapeEdges, _previousShapeUserdata, userdata)
    local finalPoints, finalUserdata, finalEdges = _previousShapePoints, _previousShapeUserdata, _previousShapeEdges

    for i = 2, #shapes.shapes do
        local shape = shapes.shapes[i]

        _shapeToPointEdges(shape, _currentShapePoints, _currentShapeEdges, _currentShapeUserdata, userdata)

        self.clipper:clip(
            clipper.union,
            _previousShapePoints, _previousShapeEdges,
            _currentShapePoints, _currentShapeEdges,
            nil,
            _previousShapeUserdata,
            _currentShapeUserdata,
            _nextShapePoints, _nextShapeEdges, _nextShapeUserdata)

        finalPoints, finalUserdata, finalEdges = _nextShapePoints, _nextShapeUserdata, _nextShapeEdges

        _previousShapePoints, _nextShapePoints = _nextShapePoints, _previousShapePoints
        _previousShapeEdges, _nextShapeEdges = _nextShapeEdges, _previousShapeEdges
        _previousShapeUserdata, _nextShapeUserdata = _nextShapeUserdata, _previousShapeUserdata
    end
    
    local m = mesh.new(finalPoints, finalUserdata, finalEdges)
    self:addMesh(t, m)
end

--- @private
--- @param options slick.geometry.clipper.clipOptions?
function navMeshBuilder:_prepareLayers(options)
    for _, layer in ipairs(self.layers) do
        local meshes = self.layerMeshes[layer.key]

        if #meshes >= 1 then
            local currentPoints, currentEdges, currentUserdata, currentExteriorEdges, currentInteriorEdges = meshes[1].inputPoints, meshes[1].edges, meshes[1].inputUserdata, meshes[1].inputExteriorEdges, meshes[1].inputInteriorEdges

            for i = 2, #meshes do
                currentPoints, currentEdges, currentUserdata, currentExteriorEdges, currentInteriorEdges = self.clipper:clip(
                    clipper.union,
                    currentPoints, { currentExteriorEdges, currentInteriorEdges },
                    meshes[i].inputPoints, { meshes[i].inputExteriorEdges, meshes[i].inputInteriorEdges },
                    options,
                    currentUserdata,
                    meshes[i].inputUserdata,
                    {}, {}, {}, {}, {})
            end

            layer.mesh = mesh.new(currentPoints, currentUserdata, currentExteriorEdges, currentInteriorEdges)
        end
    end
end

--- @private
--- @param options slick.geometry.clipper.clipOptions?
function navMeshBuilder:_combineLayers(options)
    local currentPoints, currentEdges, currentUserdata, currentExteriorEdges, currentInteriorEdges = self.layers[1].mesh.inputPoints, self.layers[1].mesh.edges, self.layers[1].mesh.inputUserdata, self.layers[1].mesh.inputExteriorEdges, self.layers[1].mesh.inputInteriorEdges

    for i = 2, #self.layers do
        local layer = self.layers[i]

        local func
        if layer.combineMode == "union" then
            func = clipper.union
        elseif layer.combineMode == "difference" then
            func = clipper.difference
        end

        if func and layer.mesh then
            currentPoints, currentEdges, currentUserdata, currentExteriorEdges, currentInteriorEdges = self.clipper:clip(
                func,
                currentPoints, { currentExteriorEdges, currentInteriorEdges },
                layer.mesh.inputPoints, { layer.mesh.inputExteriorEdges, layer.mesh.inputInteriorEdges },
                options,
                currentUserdata,
                layer.mesh.inputUserdata,
                {}, {}, {}, {}, {})
        end
    end

    if #self.layers == 1 then
        currentPoints, currentEdges, currentUserdata = self.cache.triangulator:clean(currentPoints, currentEdges, currentUserdata, options)
    end

    return currentPoints, currentExteriorEdges, currentUserdata
end

--- @param options slick.geometry.clipper.clipOptions?
function navMeshBuilder:build(options)
    self:_prepareLayers(options)

    local points, edges, userdata = self:_combineLayers(options)
    local triangles = self.cache.triangulator:triangulate(points, edges, triangulationOptions)

    return mesh.new(points, userdata, edges, triangles)
end

return navMeshBuilder
