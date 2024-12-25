local point = require("slick.geometry.point")
local slicktable = require("slick.util.slicktable")

--- @class slick.worldQueryResponse
--- @field item any
--- @field entity slick.entity
--- @field shape slick.collision.shape
--- @field normal slick.geometry.point
--- @field depth number
--- @field firstTime number
--- @field lastTime number
--- @field extra table
local worldQueryResponse = {}
local metatable = { __index = worldQueryResponse }

--- @return slick.worldQueryResponse
function worldQueryResponse.new()
    return setmetatable({
        normal = point.new(),
        depth = 0,
        firstTime = 0,
        lastTime = 0,
        metatable = {}
    }, metatable)
end

--- @param shape slick.collision.shape
--- @param normal slick.geometry.point
--- @param depth number
--- @param firstTime number
--- @param lastTime number
function worldQueryResponse:init(shape, normal, depth, firstTime, lastTime)
    self.shape = shape
    self.entity = shape.entity
    self.item = shape.entity.item
    self.normal:init(normal.x, normal.y)
    self.depth = depth
    self.firstTime = firstTime
    self.lastTime = lastTime

    slicktable.clear(self.extra)
end

return worldQueryResponse
