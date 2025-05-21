local point = require("slick.geometry.point")
local slickmath = require("slick.util.slickmath")

--- @class slick.geometry.ray
--- @field origin slick.geometry.point
--- @field direction slick.geometry.point
local ray = {}
local metatable = { __index = ray }

--- @param origin slick.geometry.point?
--- @param direction slick.geometry.point?
--- @return slick.geometry.ray
function ray.new(origin, direction)
    local result = setmetatable({
        origin = point.new(origin and origin.x, origin and origin.y),
        direction = point.new(direction and direction.x, direction and direction.y),
    }, metatable)

    if result.direction:lengthSquared() > 0 then
        result.direction:normalize(result.direction)
    end

    return result
end

--- @param origin slick.geometry.point
--- @param direction slick.geometry.point
function ray:init(origin, direction)
    self.origin:init(origin.x, origin.y)
    self.direction:init(direction.x, direction.y)
    self.direction:normalize(self.direction)
end

--- @param distance number
--- @param result slick.geometry.point
function ray:project(distance, result)
    result:init(self.direction.x, self.direction.y)
    result:multiplyScalar(distance, result)
    self.origin:add(result, result)
end

local _cachedHitSegmentPointA = point.new()
local _cachedHitSegmentPointB = point.new()
local _cachedHitSegmentPointC = point.new()
local _cachedHitSegmentPointD = point.new()
local _cachedHitSegmentResult = point.new()
local _cachedHitSegmentDirection = point.new()

--- @param s slick.geometry.segment
--- @param E number?
--- @return boolean, number?, number?, number?
function ray:hitSegment(s, E)
    E = E or 0

    _cachedHitSegmentPointA:init(s.a.x, s.a.y)
    _cachedHitSegmentPointB:init(s.b.x, s.b.y)

    _cachedHitSegmentPointC:init(self.origin.x, self.origin.y)
    self.origin:add(self.direction, _cachedHitSegmentPointD)

    local bax = _cachedHitSegmentPointB.x - _cachedHitSegmentPointA.x
    local bay = _cachedHitSegmentPointB.y - _cachedHitSegmentPointA.y
    local dcx = _cachedHitSegmentPointD.x - _cachedHitSegmentPointC.x
    local dcy = _cachedHitSegmentPointD.y - _cachedHitSegmentPointC.y

    local baCrossDC = bax * dcy - bay * dcx
    local dcCrossBA = dcx * bay - dcy * bax
    if baCrossDC == 0 or dcCrossBA == 0 then
        return false
    end

    local acx = _cachedHitSegmentPointA.x - _cachedHitSegmentPointC.x
    local acy = _cachedHitSegmentPointA.y - _cachedHitSegmentPointC.y

    local dcCrossAC = dcx * acy - dcy * acx

    local u = dcCrossAC / baCrossDC
    if u < -E or u > (1 + E) then
        return false
    end


    local rx = _cachedHitSegmentPointA.x + bax * u
    local ry = _cachedHitSegmentPointA.y + bay * u

    _cachedHitSegmentResult:init(rx, ry)
    self.origin:direction(_cachedHitSegmentResult, _cachedHitSegmentDirection)
    if _cachedHitSegmentDirection:dot(self.direction) < 0 then
        return false
    end

    return true, rx, ry, u
end

--- @param r slick.geometry.rectangle
--- @return boolean, number?, number?
function ray:hitRectangle(r)
    -- https://tavianator.com/fast-branchless-raybounding-box-intersections/
    local inverseDirectionX = 1 / self.direction.x
    local inverseDirectionY = 1 / self.direction.y
    local tMin, tMax

    local tx1 = (r:left() - self.origin.x) * inverseDirectionX
    local tx2 = (r:right() - self.origin.x) * inverseDirectionX

    tMin = math.min(tx1, tx2)
    tMax = math.max(tx1, tx2)

    local ty1 = (r:top() - self.origin.y) * inverseDirectionY
    local ty2 = (r:bottom() - self.origin.y) * inverseDirectionY

    tMin = math.max(tMin, math.min(ty1, ty2))
    tMax = math.min(tMax, math.max(ty1, ty2))

    if tMax >= tMin then
        return true, self.origin.x + self.direction.x * tMin, self.origin.y + self.direction.y * tMin
    else
        return false
    end
end

return ray
