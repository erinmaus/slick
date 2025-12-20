local point = require("slick.geometry.point")

--- @class slick.geometry.triangulation.map
--- @field point slick.geometry.point
--- @field index number
--- @field userdata any?
--- @field otherIndex number
--- @field otherUserdata any?
local map = {}
local metatable = { __index = map }

function map.new()
    return setmetatable({
        point = point.new()
    }, metatable)
end

--- @param p slick.geometry.point
--- @param oldIndex number
--- @param newIndex number
function map:init(p, oldIndex, newIndex)
    self.point:init(p.x, p.y)
    self.oldIndex = oldIndex
    self.newIndex = newIndex
end

--- @param d slick.geometry.triangulation.map
function map.default(d)
    -- No-op.
end

return map
