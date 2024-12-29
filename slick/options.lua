local slickmath = require "slick.util.slickmath"

--- @class slick.options
--- @field epsilon number?
--- @field maxBounces number?
--- @field minBounceDepth number?
--- @field debug boolean?
--- @field quadTreeX number?
--- @field quadTreeY number?
--- @field quadTreeMaxLevels number?
--- @field quadTreeMaxData number?
--- @field quadTreeExpand boolean?
--- @field sharedCache slick.cache?
local defaultOptions = {
    debug = false,

    maxBounces = 8,

    -- For simulations using pixel-sized units, this means require at least
    -- 1 pixel of penetration when following bounces. Modify for simulations using
    -- other units as appropriate.
    minBounceDepth = 1,

    quadTreeMaxLevels = 8,
    quadTreeMaxData = 8,
    quadTreeExpand = true
}

--- @type slick.options
local defaultOptionsWrapper = setmetatable(
    {},
    {
        __metatable = true,
        __index = defaultOptions,
        __newindex = function()
            error("default options is immutable", 2)
        end
    })

return defaultOptionsWrapper
