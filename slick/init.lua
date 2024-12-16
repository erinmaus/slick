local PATH = (...):gsub("[^%.]+$", "")

local slick = {}

local function load()
    slick.geometry = require("slick.geometry")
    slick.shape = require("slick.shape")
end

do
    local basePath = PATH:gsub("%.", "/")
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

return slick
