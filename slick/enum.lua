--- @class slick.enum
--- @field value any
local enum = {}
local metatable = { __index = enum }

function enum.new(value)
    return setmetatable({
        value = value
    }, metatable)
end

return enum
