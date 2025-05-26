local commonShape = require("slick.collision.commonShape")
local transform = require("slick.geometry.transform")

--- @class slick.collision.box: slick.collision.commonShape
local box = setmetatable({}, { __index = commonShape })
local metatable = { __index = box }

--- @param entity slick.entity | slick.cache | nil
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @return slick.collision.box
function box.new(entity, x, y, w, h)
    local result = setmetatable(commonShape.new(entity), metatable)

    --- @cast result slick.collision.box
    result:init(x, y, w, h)
    return result
end

--- @param x number
--- @param y number
--- @param w number
--- @param h number
function box:init(x, y, w, h)
    commonShape.init(self)

    self:addPoints(
        x, y,
        x + w, y,
        x + w, y + h,
        x, y + h)

    self:addNormal(0, 1)
    self:addNormal(-1, 0)
    self:addNormal(0, -1)
    self:addNormal(1, 0)

    self:transform(transform.IDENTITY)

    assert(self.vertexCount == 4, "box must have 4 points")
    assert(self.normalCount == 4, "box must have 4 normals")
end

function box:inside(p)
    return p.x >= self.bounds:left() and p.x <= self.bounds:right() and p.y >= self.bounds:top() and p.y <= self.bounds:bottom()
end

return box
