local PATH = (...):gsub("[^%.]+$", "")

--- @module "slick.cache"
local cache

--- @module "slick.collision"
local collision

--- @module "slick.draw"
local draw

--- @module "slick.entity"
local entity

--- @module "slick.geometry"
local geometry

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
    cache = require("slick.cache")
    collision = require("slick.collision")
    draw = require("slick.draw")
    entity = require("slick.entity")
    geometry = require("slick.geometry")
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
    local basePath = PATH:gsub("%.", "/")
    if basePath == "" then
        basePath = "./"
    end

    local pathPrefix = string.format("%s?.lua;%s?/init.lua", basePath, basePath)

    local oldLuaPath = package.path
    local oldLovePath = love and love.filesystem and love.filesystem.getRequirePath()

    local newLuaPath = string.format("%s;%s", pathPrefix, oldLuaPath)
    package.path = newLuaPath

    if oldLovePath then
        local newLovePath = string.format("%s;%s", pathPrefix, oldLovePath)
        love.filesystem.setRequirePath(newLovePath)
    end

    local success, result = xpcall(load, debug.traceback)

    package.path = oldLuaPath
    if oldLovePath then
        love.filesystem.setRequirePath(oldLovePath)
    end

    if not success then
        error(result, 0)
    end
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
    newCircleShape = shape.newCircle,
    newLineSegmentShape = shape.newLineSegment,
    newPolygonShape = shape.newPolygon,
    newPolylineShape = shape.newPolyline,
    newPolygonMeshShape = shape.newPolygonMesh,
    newMeshShape = shape.newMesh,
    newShapeGroup = shape.newShapeGroup,
    newTag = tag.new,

    triangulate = geometry.simple.triangulate,
    polygonize = geometry.simple.polygonize,
    clip = geometry.simple.clip,

    newUnionClipOperation = geometry.simple.newUnionClipOperation,
    newIntersectionClipOperation = geometry.simple.newIntersectionClipOperation,
    newDifferenceClipOperation = geometry.simple.newDifferenceClipOperation,

    drawWorld = draw
}
