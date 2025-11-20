local slickmath = {}

slickmath.EPSILON = 1e-5

--- @param value number
--- @param increment number
--- @param max number
--- @return number
function slickmath.wrap(value, increment, max)
    return (value + increment - 1) % max + 1
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param c slick.geometry.point
--- @return number
function slickmath.angle(a, b, c)
    local abx = a.x - b.x
    local aby = a.y - b.y
    local cbx = c.x - b.x
    local cby = c.y - b.y

    local abLength = math.sqrt(abx ^ 2 + aby ^ 2)
    local cbLength = math.sqrt(cbx ^ 2 + cby ^ 2)

    if abLength == 0 or cbLength == 0 then
        return 0
    end

    local abNormalX = abx / abLength
    local abNormalY = aby / abLength
    local cbNormalX = cbx / cbLength
    local cbNormalY = cby / cbLength

    local dot = abNormalX * cbNormalX + abNormalY * cbNormalY
    if not (dot >= -1 and dot <= 1) then
        return 0
    end

    return math.acos(dot)
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @return number
function slickmath.cross(a, b, c)
    local left = (a.y - c.y) * (b.x - c.x)
    local right = (a.x - c.x) * (b.y - c.y)

    return left - right
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param c slick.geometry.point
--- @param E number?
--- @return -1 | 0 | 1
function slickmath.direction(a, b, c, E)
    local result = slickmath.cross(a, b, c)
    return slickmath.sign(result, E)
end

--- Checks if `d` is inside the circumscribed circle created by `a`, `b`, and `c`
--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param c slick.geometry.point
--- @param d slick.geometry.point
--- @return -1 | 0 | 1
function slickmath.inside(a, b, c, d)
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
    
    return slickmath.sign(result)
end

local function _collinear(a, b, c, d, E)
    local abl = math.min(a, b)
    local abh = math.max(a, b)

    local cdl = math.min(c, d)
    local cdh = math.max(c, d)

    if cdh + E < abl or abh + E < cdl then
        return false
    end

    return true
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param c slick.geometry.point
--- @param d slick.geometry.point
--- @return boolean
function slickmath.collinear(a, b, c, d, E)
    E = E or 0

    local acdSign = slickmath.direction(a, c, d, E)
    local bcdSign = slickmath.direction(b, c, d, E)
    local cabSign = slickmath.direction(c, a, b, E)
    local dabSign = slickmath.direction(d, a, b, E)

    if acdSign == 0 and bcdSign == 0 and cabSign == 0 and dabSign == 0 then
        return _collinear(a.x, b.x, c.x, d.x, E) and _collinear(a.y, b.y, c.y, d.y, E)
    end

    return false
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param c slick.geometry.point
--- @param d slick.geometry.point
--- @param E number?
--- @return boolean, number?, number?, number?, number?
function slickmath.intersection(a, b, c, d, E)
    E = E or 0

    local acdSign = slickmath.direction(a, c, d, E)
    local bcdSign = slickmath.direction(b, c, d, E)
    if (acdSign < 0 and bcdSign < 0) or (acdSign > 0 and bcdSign > 0) then
        return false
    end

    local cabSign = slickmath.direction(c, a, b, E)
    local dabSign = slickmath.direction(d, a, b, E)
    if (cabSign < 0 and dabSign < 0) or (cabSign > 0 and dabSign > 0) then
        return false
    end

    if acdSign == 0 and bcdSign == 0 and cabSign == 0 and dabSign == 0 then
        return slickmath.collinear(a, b, c, d, E)
    end

    local bax = b.x - a.x
    local bay = b.y - a.y
    local dcx = d.x - c.x
    local dcy = d.y - c.y

    local baCrossDC = bax * dcy - bay * dcx
    local dcCrossBA = dcx * bay - dcy * bax
    if baCrossDC == 0 or dcCrossBA == 0 then
        return false
    end

    local acx = a.x - c.x
    local acy = a.y - c.y
    local cax = c.x - a.x
    local cay = c.y - a.y

    local dcCrossAC = dcx * acy - dcy * acx
    local baCrossCA = bax * cay - bay * cax
    
    local u = dcCrossAC / baCrossDC
    local v = baCrossCA / dcCrossBA

    if u < -E or u > (1 + E) or v < -E or v > (1 + E) then
        return false
    end

    local rx = a.x + bax * u
    local ry = a.y + bay * u

    return true, rx, ry, u, v
end

--- @param s slick.geometry.segment
--- @param p slick.geometry.point
--- @param r number
--- @param E number?
--- @return boolean, number?, number?
function slickmath.lineCircleIntersection(s, p, r, E)
    E = E or 0

    local p1 = s.a
    local p2 = s.b

    local rSquared = r ^ 2

    local dx = p2.x - p1.x
    local dy = p2.y - p1.y

    local fx = p1.x - p.x
    local fy = p1.y - p.y

    local a = dx ^ 2 + dy ^ 2
    local b = 2 * (dx * fx + dy * fy)
    local c = fx ^ 2 + fy ^ 2 - rSquared

    local d = b ^ 2 - 4 * a * c
    if a <= 0 or d < -E then
        return false, nil, nil
    end

    d = math.sqrt(math.max(d, 0))

    local u = (-b - d) / (2 * a)
    local v = (-b + d) / (2 * a)

    return true, u, v
end

--- @param p1 slick.geometry.point
--- @param r1 number
--- @param p2 slick.geometry.point
--- @param r2 number
--- @return boolean, number?, number?, number?, number?
function slickmath.circleCircleIntersection(p1, r1, p2, r2)
    local nx = p2.x - p1.x
    local ny = p2.y - p1.y

    local radius = r1 + r2
    local magnitude = nx ^ 2 + ny ^ 2
    if magnitude <= radius ^ 2 then
        if magnitude == 0 then
            return true, nil, nil, nil, nil
        elseif magnitude < math.abs(r1 - r2) ^ 2 then
            return true, nil, nil, nil, nil
        end

        local d = math.sqrt(magnitude)

        if d > 0 then
            nx = nx / d
            ny = ny / d
        end

        local a = (r1 ^ 2 - r2 ^ 2 + magnitude) / (2 * d)
        local h = math.sqrt(r1 ^ 2 - a ^ 2)

        local directionX = p2.x - p1.x
        local directionY = p2.y - p1.y
        local p3x = p1.x + a * directionX / d
        local p3y = p1.y + a * directionY / d

        local result1X = p3x + h * directionY / d
        local result1Y = p3y - h * directionX / d

        local result2X = p3x - h * directionY / d
        local result2Y = p3y + h * directionX / d

        return true, result1X, result1Y, result2X, result2Y
    end

    return false, nil, nil, nil, nil
end

--- @param value number
--- @param E number?
--- @return -1 | 0 | 1
function slickmath.sign(value, E)
    E = E or 0

    if math.abs(value) <= E then
        return 0
    end

    if value > 0 then
        return 1
    elseif value < 0 then
        return -1
    end

    return 0
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

function slickmath.withinRange(value, min, max, E)
    E = E or slickmath.EPSILON

    return value > min - E and value < max + E
end

function slickmath.equal(a, b, E)
    E = E or slickmath.EPSILON

    return math.abs(a - b) < E
end

function slickmath.less(a, b, E)
    E = E or slickmath.EPSILON

    return a < b + E
end

function slickmath.greater(a, b, E)
    E = E or slickmath.EPSILON

    return a > b - E
end

return slickmath
