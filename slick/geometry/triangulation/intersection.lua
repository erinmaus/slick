local point = require("slick.geometry.point")
local slickmath = require("slick.util.slickmath")

--- @class slick.geometry.triangulation.intersection
--- @field a1 slick.geometry.point
--- @field a1Userdata any?
--- @field b1 slick.geometry.point
--- @field b1Userdata any?
--- @field a2 slick.geometry.point
--- @field a2Userdata any?
--- @field b2 slick.geometry.point
--- @field b2Userdata any?
--- @field delta number
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
        delta = 0,
        s = point.new(),
        t = point.new(),
        p = point.new(),
        q = point.new(),
    }, metatable)
end

function intersection:setLeftEdge(a, b, aUserdata, bUserdata)
    self.a1:init(a.x, a.y)
    self.b1:init(b.x, b.y)
    self.a1Userdata = aUserdata
    self.b1Userdata = bUserdata
end

function intersection:setRightEdge(a, b, aUserdata, bUserdata)
    self.a2:init(a.x, a.y)
    self.b2:init(b.x, b.y)
    self.a2Userdata = aUserdata
    self.b2Userdata = bUserdata
end

function intersection:computeDelta(E)
    self.b1:sub(self.a1, self.s)
    self.b2:sub(self.a2, self.t)

    local sCrossT = slickmath.cross(self.s, self.t)
    if slickmath.sign(sCrossT, E) == 0 then
        self.delta = 0
        return
    end

    self.a1:sub(self.a2, self.p)
    local tCrossP = slickmath.cross(self.t, self.p)

    self.delta = tCrossP / sCrossT
end

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
