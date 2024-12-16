local slickmath = {}

slickmath.EPSILON = 0.01

--- @param a number
--- @param b number
--- @param E number
--- @return boolean
function slickmath.equal(a, b, E)
    return math.abs(a - b) < E
end

--- @param a number
--- @param b number
--- @param E number
--- @return boolean
function slickmath.greater(a, b, E)
    return a > b + E
end

--- @param a number
--- @param b number
--- @param E number
--- @return boolean
function slickmath.less(a, b, E)
    return a < b - E
end

--- @param min number
--- @param max number
--- @param rng love.RandomGenerator?
--- @return number
function slickmath.random(min, max, rng)
    if rng then
        return rng:random(min, max)
    end

    if love and love.math then
        return love.math.random(min, max)
    end

    return math.random(min, max)
end

return slickmath
