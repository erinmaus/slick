local point = require("slick.geometry.point")
local slickmath = require("slick.util.slickmath")

--- @class slick.geometry.triangulation.intersection
--- @field a1 slick.geometry.point
--- @field a1Userdata any?
--- @field b1 slick.geometry.point
--- @field b1Userdata any?
--- @field delta1 number
--- @field a2 slick.geometry.point
--- @field a2Userdata any?
--- @field b2 slick.geometry.point
--- @field b2Userdata any?
--- @field delta2 number
--- @field result slick.geometry.point
--- @field resultIndex number
--- @field resultUserdata any?
--- @field private s slick.geometry.point
--- @field private t slick.geometry.point
--- @field private p slick.geometry.point
--- @field private q slick.geometry.point
local intersection = {}
local metatable = { __index = intersection }

function intersection.new()
    return setmetatable({
        a1 = point.new(),
        b1 = point.new(),
        a2 = point.new(),
        b2 = point.new(),
        result = point.new(),
        delta1 = 0,
        delta2 = 0,
        s = point.new(),
        t = point.new(),
        p = point.new(),
        q = point.new(),
    }, metatable)
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param delta number
--- @param aUserdata any
--- @param bUserdata any
function intersection:setLeftEdge(a, b, delta, aUserdata, bUserdata)
    self.a1:init(a.x, a.y)
    self.b1:init(b.x, b.y)
    self.a1Userdata = aUserdata
    self.b1Userdata = bUserdata
    self.delta1 = delta
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param delta number
--- @param aUserdata any
--- @param bUserdata any
function intersection:setRightEdge(a, b, delta, aUserdata, bUserdata)
    self.a2:init(a.x, a.y)
    self.b2:init(b.x, b.y)
    self.a2Userdata = aUserdata
    self.b2Userdata = bUserdata
    self.delta2 = delta
end

--- @param resultIndex number
function intersection:init(resultIndex)
    self.a1Userdata = nil
    self.b1Userdata = nil
    self.a2Userdata = nil
    self.b2Userdata = nil
    self.resultUserdata = nil
    self.resultIndex = resultIndex
end

--- @param i slick.geometry.triangulation.intersection
function intersection.default(i)
    -- No-op.
end

--- @param userdata any?
--- @param x number?
--- @param y number?
function intersection:setResult(userdata, x, y)
    self.resultUserdata = userdata

    if x and y then
        self.result:init(x, y)
    end
end

return intersection
