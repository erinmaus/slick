local point = require("slick.geometry.point")

--- @class slick.geometry.segment
--- @field a slick.geometry.point
--- @field b slick.geometry.point
local segment = {}
local metatable = { __index = segment }

--- @param a slick.geometry.point?
--- @param b slick.geometry.point?
--- @return slick.geometry.segment
function segment:new(a, b)
    return setmetatable({
        a = a,
        b = b
    }, metatable)
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
function segment:init(a, b)
    self.a = a
    self.b = b
end

--- @alias slick.geometry.segmentCompareFunc fun(a: slick.geometry.segment, b: slick.geometry.segment): slick.util.search.compareResult

--- @param E number
--- @return slick.geometry.segmentCompareFunc
function segment.compare(E)
    local comparePoint = point.compare(E)

    --- @param a slick.geometry.segment
    --- @param b slick.geometry.segment
    return function(a, b)
        local s = comparePoint(a.a, b.a)
        if s ~= 0 then
            return s
        end

        return comparePoint(a.b, b.b)
    end
end

--- @param other slick.geometry.segment
--- @param E number
--- @return boolean
function segment:lessThan(other, E)
    return self.a:lessThan(other.a, E) or
           (self.a:equal(other.a, E) and self.b:lessThan(other.b, E))
end

return segment
