local point = require("slick.geometry.point")

--- @class slick.geometry.triangulation.dissolve
--- @field point slick.geometry.point
--- @field index number
--- @field userdata any?
local dissolve = {}
local metatable = { __index = dissolve }

function dissolve.new()
    return setmetatable({
        point = point.new()
    }, metatable)
end

--- @param p slick.geometry.point
--- @param index number
--- @param userdata any?
function dissolve:init(p, index, userdata)
    self.point:init(p.x, p.y)
    self.index = index
    self.userdata = userdata
end

--- @param d slick.geometry.triangulation.dissolve
function dissolve.default(d)
    -- No-op.
end

return dissolve
