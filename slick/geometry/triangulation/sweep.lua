local slickmath = require("slick.util.slickmath")
local point = require("slick.geometry.point")
local segment = require("slick.geometry.segment")
local util = require("slick.util")

--- @class slick.geometry.triangulation.sweep
--- @field type slick.geometry.triangulation.sweepType
--- @field data slick.geometry.point | slick.geometry.segment
--- @field point slick.geometry.point?
--- @field index number
local sweep = {}
local metatable = { __index = sweep }

--- @alias slick.geometry.triangulation.sweepType 0 | 1 | 2 | 3
sweep.TYPE_NONE       = 0
sweep.TYPE_POINT      = 1
sweep.TYPE_EDGE_STOP  = 2
sweep.TYPE_EDGE_START = 3

--- @return slick.geometry.triangulation.sweep
function sweep.new()
    return setmetatable({
        type = sweep.TYPE_NONE,
        index = 0
    }, metatable)
end

--- @param data slick.geometry.point | slick.geometry.segment
--- @return slick.geometry.point
local function _getPointFromData(data)
    if util.is(data, segment) then
        return data.a
    elseif util.is(data, point) then
        --- @cast data slick.geometry.point
        return data
    end

    --- @diagnostic disable-next-line: missing-return
    assert(false, "expected 'slick.geometry.point' or 'slick.geometry.segment'")
end

--- @param a slick.geometry.triangulation.sweep
--- @param b slick.geometry.triangulation.sweep
--- @return boolean
function sweep.less(a, b)
    if a.point:lessThan(b.point) then
        return true
    elseif a.point:equal(b.point) then
        if a.type < b.type then
            return true
        elseif a.type == b.type then
            if a.type == sweep.TYPE_EDGE_START or a.type == sweep.TYPE_EDGE_STOP then
                local direction = slickmath.direction(a.point, b.point, b.data.b)
                if direction ~= 0 then
                    return direction < 0
                end
            end
            
            return a.index < b.index
        else
            return false
        end
    else
        return false
    end
end

--- @param sweepType slick.geometry.triangulation.sweepType
--- @param data slick.geometry.point | slick.geometry.segment
--- @param index number
function sweep:init(sweepType, data, index)
    self.type = sweepType
    self.data = data
    self.index = index
    self.point = _getPointFromData(data)
end

return sweep
