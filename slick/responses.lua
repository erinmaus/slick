local point = require "slick.geometry.point"

local _cachedSlideNormal = point.new()
local _cachedSlideCurrentPosition = point.new()
local _cachedSlideGoalPosition = point.new()
local _cachedSlideActualPosition = point.new()
local _cachedSlideDirection = point.new()

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param filter slick.worldFilterQueryFunc
--- @return number, number, slick.worldQueryResponse[], number, slick.worldQuery
local function slide(world, query, response, x, y, filter)
    _cachedSlideCurrentPosition:init(response.entity.transform.x, response.entity.transform.y)
    _cachedSlideGoalPosition:init(x, y)

    _cachedSlideCurrentPosition:direction(_cachedSlideGoalPosition, _cachedSlideDirection)

    local distanceToGoal = _cachedSlideCurrentPosition:distance(_cachedSlideGoalPosition)
    if distanceToGoal > 0 then
        _cachedSlideDirection:divideScalar(distanceToGoal, _cachedSlideDirection)
    end

    local actualX, actualY
    if response.time > 0 and response.time < 1 then
        actualX = x + response.offset.x
        actualY = y + response.offset.y

        _cachedSlideNormal:init(response.offset.x, response.offset.y)
        if _cachedSlideNormal:lengthSquared() > 0 then
            _cachedSlideNormal:normalize(_cachedSlideNormal)
        end
    elseif response.depth > 0 then
        actualX = x + response.normal.x * response.depth
        actualY = y + response.normal.y * response.depth

        _cachedSlideNormal:init(response.normal.x, response.normal.y)
    end

    _cachedSlideActualPosition:init(actualX, actualY)
    local distanceFromStart = _cachedSlideCurrentPosition:distance(_cachedSlideActualPosition)
    local remainingDistance = distanceToGoal - distanceFromStart
    
    _cachedSlideNormal:left(_cachedSlideNormal)
    local d = _cachedSlideDirection:dot(_cachedSlideNormal)
    if d < 0 then
        _cachedSlideNormal:negate(_cachedSlideNormal)
    end

    _cachedSlideNormal:multiplyScalar(remainingDistance, _cachedSlideNormal)
    _cachedSlideNormal:add(_cachedSlideActualPosition, _cachedSlideActualPosition)

    actualX = actualX + _cachedSlideNormal.x
    actualY = actualY + _cachedSlideNormal.y

    return actualX, actualY, world:project(response.item, actualX, actualY, filter, query)
end

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param filter slick.worldFilterQueryFunc
--- @return number, number, slick.worldQueryResponse[], number, slick.worldQuery
local function touch(world, query, response, x, y, filter)
    if response.time > 0 and response.time < 1 then
        x = x + response.offset.x
        y = y + response.offset.y
    elseif response.depth > 0 then
        x = x + response.normal.x * response.depth
        y = y + response.normal.y * response.depth
    end

    query:reset()

    return x, y, query.results, 0, query
end

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param filter slick.worldFilterQueryFunc
--- @return number, number, slick.worldQueryResponse[], number, slick.worldQuery
local function cross(world, query, response, x, y, filter)
    return x, y, world:project(response.item, x, y, filter, query)
end

return {
    slide = slide,
    touch = touch,
    cross = cross
}
