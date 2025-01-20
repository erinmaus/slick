--- @class slick.tag
--- @field value any
local tag = {}
local metatable = { __index = tag }

function tag.new(value)
    return setmetatable({
        value = value
    }, metatable)
end

return tag
