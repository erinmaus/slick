local slick = require "slick"

--- @param a number
--- @param b number
--- @param E number?
--- @return boolean
local function equalish(a, b, E)
    E = E or slick.util.math.EPSILON
    return math.abs(a - b) <= E
end

return {
    equalish = equalish
}