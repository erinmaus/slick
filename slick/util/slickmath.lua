local slickmath = {}

slickmath.EPSILON = 0.01

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param c slick.geometry.point
--- @param E number
--- @return -1 | 0 | 1
function slickmath.direction(a, b, c, E)
    local left = (a.y - c.y) * (b.x - c.x)
    local right = (a.x - c.x) * (b.y - c.y)
    local result = left - right
    
    return slickmath.sign(result, E)
end

--- Checks if `d` is inside the circumscribed circle created by `a`, `b`, and `c`
--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param c slick.geometry.point
--- @param d slick.geometry.point
--- @param E number
--- @return -1 | 0 | 1
function slickmath.inside(a, b, c, d, E)
    local ax = a.x - d.x
    local ay = a.y - d.y
    local bx = b.x - d.x
    local by = b.y - d.y
    local cx = c.x - d.x
    local cy = c.y - d.y

    local i = (ax * ax + ay * ay) * (bx * cy - cx * by)
    local j = (bx * bx + by * by) * (ax * cy - cx * ay)
    local k = (cx * cx + cy * cy) * (ax * by - bx * ay)
    local result = i - j + k
    
    return slickmath.sign(result, E)
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @return number
function slickmath.cross(a, b)
    return a.x * b.y - a.y * b.x
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param c slick.geometry.point
--- @param d slick.geometry.point
--- @param E number
--- @return boolean, number?, number?
function slickmath.intersection(a, b, c, d, E)
    local bax = b.x - a.x
    local bay = b.y - a.y
    local dcx = d.x - c.x
    local dcy = d.y - c.y

    local cax = c.x - a.x
    local cay = c.y - a.y

    local caCrossBa = cax * bay - cay * bax
    local caCrossDc = cax * dcy - cay * dcx
    local baCrossDc = bax * dcy - bay * dcx

    if slickmath.equal(caCrossBa, 0, E) then
        local cbx = c.x - b.x
        local cby = c.y - b.y

        return slickmath.sign(cax, E) ~= slickmath.sign(cbx, E) or slickmath.sign(cay, E) ~= slickmath.sign(cby, E), nil, nul
    end

    if slickmath.equal(baCrossDc, 0, E) then
        return false, nil, nil
    end

    local p = 1 / baCrossDc
    local u = caCrossBa * p 
    local v = caCrossDc * p

    if u > -E and u < (1 + E) and v > -E and v < (1 + E) then
        return true, a.x + v * bax, a.y + v * bay
    end

    return false, nil, nil
end

--- @param value number
--- @param E number
--- @return -1 | 0 | 1
function slickmath.sign(value, E)
    if slickmath.greater(value, 0, E) then
        return 1
    elseif slickmath.less(value, 0, E) then
        return -1
    end

    return 0
end

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
