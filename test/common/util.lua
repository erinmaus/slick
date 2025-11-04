local slick = require "slick"

--- @param a number
--- @param b number
--- @param E number?
--- @return boolean
local function equalish(a, b, E)
    E = E or slick.util.math.EPSILON
    return math.abs(a - b) <= E
end

--- @param t slick.geometry.point[]
--- @param x number
--- @param y number
--- @param E number?
--- @return boolean
local function hasPoint(t, x, y, E)
    for _, p in ipairs(t) do
        if equalish(p.x, x, E) and equalish(p.y, y, E) then
            return true
        end
    end

    return false
end

return {
    equalish = equalish,
    hasPoint = hasPoint
}