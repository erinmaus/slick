local point = require("slick.geometry.point")

--- @class slick.geometry.triangulation.dissolve
--- @field point slick.geometry.point
--- @field index number
--- @field userdata any?
--- @field otherIndex number
--- @field otherUserdata any?
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
--- @param otherIndex number
--- @param otherUserdata any
function dissolve:init(p, index, userdata, otherIndex, otherUserdata)
    self.point:init(p.x, p.y)
    self.index = index
    self.userdata = userdata
    self.otherIndex = otherIndex
    self.otherUserdata = otherUserdata
    self.resultUserdata = nil
end

--- @param d slick.geometry.triangulation.dissolve
function dissolve.default(d)
    -- No-op.
end

return dissolve
