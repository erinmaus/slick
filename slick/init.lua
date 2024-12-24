local PATH = (...):gsub("[^%.]+$", "")

--- @module "slick.collision"
local collision

--- @module "slick.geometry"
local geometry

--- @module "slick.shape"
local shape

--- @module "slick.util"
local util

local function load()
    collision = require("slick.collision")
    geometry = require("slick.geometry")
    shape = require("slick.shape")
    util = require("slick.util")
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

return {
    collision = collision,
    geometry = geometry,
    shape = shape,
    util = util,
}
