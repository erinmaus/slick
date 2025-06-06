local PATH = (...):gsub("[^%.]+$", "")

--- @module "slick.cache"
local cache

--- @module "slick.collision"
local collision

--- @module "slick.draw"
local draw

--- @module "slick.entity"
local entity

--- @module "slick.enum"
local enum

--- @module "slick.geometry"
local geometry

--- @module "slick.navigation"
local navigation

--- @module "slick.options"
local defaultOptions

--- @module "slick.responses"
local responses

--- @module "slick.shape"
local shape

--- @module "slick.tag"
local tag

--- @module "slick.util"
local util

--- @module "slick.world"
local world

--- @module "slick.worldQuery"
local worldQuery

--- @module "slick.worldQueryResponse"
local worldQueryResponse

--- @module "slick.meta"
local meta

local function load()
    local requireImpl = require
    local require = function(path)
        return requireImpl(PATH .. path)
    end

    local patchedG = {
        __index = _G
    }

    local g = { require = require }
    g._G = g

    setfenv(0, setmetatable(g, patchedG))

    cache = require("slick.cache")
    collision = require("slick.collision")
    draw = require("slick.draw")
    entity = require("slick.entity")
    enum = require("slick.enum")
    geometry = require("slick.geometry")
    navigation = require("slick.navigation")
    defaultOptions = require("slick.options")
    responses = require("slick.responses")
    shape = require("slick.shape")
    tag = require("slick.tag")
    util = require("slick.util")
    world = require("slick.world")
    worldQuery = require("slick.worldQuery")
    worldQueryResponse = require("slick.worldQueryResponse")

    meta = require("slick.meta")
end

do
    local l = coroutine.create(load)
    repeat
        local s, r = coroutine.resume(l)
        if not s then
            error(debug.traceback(l, r))
        end
    until coroutine.status(l) == "dead"
end

return {
    _VERSION = meta._VERSION,
    _DESCRIPTION = meta._DESCRIPTION,
    _URL = meta._URL,
    _LICENSE = meta._LICENSE,

    cache = cache,
    collision = collision,
    defaultOptions = defaultOptions,
    entity = entity,
    geometry = geometry,
    shape = shape,
    tag = tag,
    util = util,
    world = world,
    worldQuery = worldQuery,
    worldQueryResponse = worldQueryResponse,
    responses = responses,

    newCache = cache.new,
    newWorld = world.new,
    newWorldQuery = worldQuery.new,
    newTransform = geometry.transform.new,

    newRectangleShape = shape.newRectangle,
    newChainShape = shape.newChain,
    newCircleShape = shape.newCircle,
    newLineSegmentShape = shape.newLineSegment,
    newPolygonShape = shape.newPolygon,
    newPolygonMeshShape = shape.newPolygonMesh,
    newPolylineShape = shape.newPolyline,
    newMeshShape = shape.newMesh,
    newShapeGroup = shape.newShapeGroup,
    newEnum = enum.new,
    newTag = tag.new,

    triangulate = geometry.simple.triangulate,
    polygonize = geometry.simple.polygonize,
    clip = geometry.simple.clip,

    newUnionClipOperation = geometry.simple.newUnionClipOperation,
    newIntersectionClipOperation = geometry.simple.newIntersectionClipOperation,
    newDifferenceClipOperation = geometry.simple.newDifferenceClipOperation,

    navigation = navigation,

    drawWorld = draw
}
