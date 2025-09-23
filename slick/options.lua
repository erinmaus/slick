--- @class slick.options
--- @field epsilon number?
--- @field maxBounces number?
--- @field maxJitter number?
--- @field debug boolean?
--- @field quadTreeX number?
--- @field quadTreeY number?
--- @field quadTreeMaxLevels number?
--- @field quadTreeMaxData number?
--- @field quadTreeExpand boolean?
--- @field quadTreeOptimizationMargin number?
--- @field sharedCache slick.cache?
local defaultOptions = {
    debug = false,

    maxBounces = 4,
    maxJitter = 1,

    quadTreeMaxLevels = 8,
    quadTreeMaxData = 8,
    quadTreeExpand = true,
    quadTreeOptimizationMargin = 0.25
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
