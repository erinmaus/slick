local slickmath = {}

slickmath.EPSILON = 0.01

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
--- @return -1 | 0 | 1
function slickmath.direction(a, b, c)
    local result = slickmath.cross(a, b, c)
    return slickmath.sign(result)
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

local function _collinear(a, b, c, d)
    local abl = math.min(a, b)
    local abh = math.max(a, b)

    local cdl = math.min(c, d)
    local cdh = math.max(c, d)

    if cdh < abl or abh < cdl then
        return false
    end

    return true
end

--- @param a slick.geometry.point
--- @param b slick.geometry.point
--- @param c slick.geometry.point
--- @param d slick.geometry.point
--- @return boolean, number?, number?, number?, number?
function slickmath.intersection(a, b, c, d)
    local acdSign = slickmath.direction(a, c, d)
    local bcdSign = slickmath.direction(b, c, d)
    if (acdSign < 0 and bcdSign < 0) or (acdSign > 0 and bcdSign > 0) then
        return false
    end
    
    local cabSign = slickmath.direction(c, a, b)
    local dabSign = slickmath.direction(d, a, b)
    if (cabSign < 0 and dabSign < 0) or (cabSign > 0 and dabSign > 0) then
        return false
    end

    if acdSign == 0 and bcdSign == 0 and cabSign == 0 and dabSign == 0 then
        return _collinear(a.x, b.x, c.x, d.x) and _collinear(a.y, b.y, c.y, d.y)
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

    local bdx = c.x - a.x
    local bdy = c.y - a.y

    local dcCrossAC = dcx * acy - dcy * acx
    local dcCrossCA = dcx * bdy - dcy * bdx

    local u = dcCrossAC / baCrossDC
    local v = dcCrossCA / dcCrossBA

    if u < 0 or u > 1 or v < 0 or v > 1 then
        return false
    end

    local rx = a.x + bax * u
    local ry = a.y + bay * u

    return true, rx, ry, u, v
end

--- @param value number
--- @return -1 | 0 | 1
function slickmath.sign(value)
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

return slickmath
