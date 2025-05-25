--- @class slick.navigation.vertex
--- @field point slick.geometry.point
--- @field userdata any
--- @field index number
local vertex = {}
local metatable = { __index = vertex }

--- @param point slick.geometry.point
--- @param userdata any
--- @param index number
function vertex.new(point, userdata, index)
    return setmetatable({
        point = point,
        userdata = userdata,
        index = index
    }, metatable)
end

return vertex
