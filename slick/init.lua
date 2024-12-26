local PATH = (...):gsub("[^%.]+$", "")

--- @module "slick.cache"
local cache

--- @module "slick.collision"
local collision

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

--- @module "slick.util"
local util

--- @module "slick.world"
local world

--- @module "slick.worldQuery"
local worldQuery

--- @module "slick.worldQueryResponse"
local worldQueryResponse

local function load()
    cache = require("slick.cache")
    collision = require("slick.collision")
    entity = require("slick.entity")
    geometry = require("slick.geometry")
    defaultOptions = require("slick.options")
    responses = require("slick.responses")
    shape = require("slick.shape")
    util = require("slick.util")
    world = require("slick.world")
    worldQuery = require("slick.worldQuery")
    worldQueryResponse = require("slick.worldQueryResponse")
end

do
    local basePath = PATH:gsub("%.", "/")
    if basePath == "" then
        basePath = "."
    end

    local pathPrefix = string.format("%s/?.lua;%s/?/init.lua", basePath, basePath)

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

--- @param options slick.options
local function newCache(options)
    return cache.new(options)
end

--- @param width number
--- @param height number
--- @param options slick.options?
local function newWorld(width, height, options)
    return world.new(width, height, options)
end

--- @param world slick.world
--- @return slick.worldQuery
local function newWorldQuery(world)
    return worldQuery.new(world)
end

return {
    cache = cache,
    collision = collision,
    defaultOptions = defaultOptions,
    entity = entity,
    geometry = geometry,
    shape = shape,
    util = util,
    world = world,
    worldQuery = worldQuery,
    worldQueryResponse = worldQueryResponse,
    responses = responses,

    newCache = newCache,
    newWorld = newWorld
}
