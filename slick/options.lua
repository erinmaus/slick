--- @class slick.options
--- @field epsilon number?
--- @field debug boolean?
--- @field quadTreeX number?
--- @field quadTreeY number?
--- @field quadTreeMaxLevels number?
--- @field quadTreeMaxData number?
--- @field quadTreeExpand boolean?
--- @field sharedCache slick.cache?
local defaultOptions = {
    epsilon = 0.01,
    debug = false,

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
