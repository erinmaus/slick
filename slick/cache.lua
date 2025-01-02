local delaunay = require("slick.geometry.triangulation.delaunay")

--- @class slick.cache
--- @field triangulator slick.geometry.triangulation.delaunay
local cache = {}
local metatable = { __index = cache }

--- @param options slick.options
function cache.new(options)
    if options.sharedCache then
        return options.sharedCache
    end

    return setmetatable({
        triangulator = delaunay.new({
            epsilon = options.epsilon,
            debug = options.debug
        })
    }, metatable)
end

return cache
