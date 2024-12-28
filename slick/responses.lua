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
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc
--- @return number, number, slick.worldQueryResponse[], number, slick.worldQuery
local function slide(world, query, response, x, y, goalX, goalY, filter)
    _cachedSlideCurrentPosition:init(x, y)
    _cachedSlideGoalPosition:init(goalX, goalY)

    _cachedSlideCurrentPosition:direction(_cachedSlideGoalPosition, _cachedSlideDirection)

    local distanceToGoal = _cachedSlideCurrentPosition:distance(_cachedSlideGoalPosition)
    if distanceToGoal > 0 then
        _cachedSlideDirection:divideScalar(distanceToGoal, _cachedSlideDirection)
    end

    local actualX, actualY
    if response.time > 0 and response.time <= 1 then
        actualX = x + response.offset.x
        actualY = y + response.offset.y
    elseif response.depth > 0 then
        actualX = goalX + response.normal.x * response.depth
        actualY = goalY + response.normal.y * response.depth
    end

    _cachedSlideNormal:init(response.normal.x, response.normal.y)

    _cachedSlideActualPosition:init(actualX, actualY)
    local distanceFromStart = _cachedSlideCurrentPosition:distance(_cachedSlideActualPosition)
    local remainingDistance = distanceToGoal - distanceFromStart
    
    _cachedSlideNormal:left(_cachedSlideNormal)

    local d = math.abs(_cachedSlideDirection:dot(_cachedSlideNormal))

    _cachedSlideNormal:multiplyScalar(remainingDistance, _cachedSlideNormal)
    _cachedSlideNormal:add(_cachedSlideActualPosition, _cachedSlideActualPosition)

    actualX = actualX + _cachedSlideNormal.x * d
    actualY = actualY + _cachedSlideNormal.y * d

    return actualX, actualY, world:project(response.item, actualX, actualY, filter, query)
end

local _cachedTouchDirection = point.new()
local _cachedTouchCurrentPosition = point.new()
local _cachedTouchGoalPosition = point.new()

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc
--- @return number, number, slick.worldQueryResponse[], number, slick.worldQuery
local function touch(world, query, response, x, y, goalX, goalY, filter)
    _cachedTouchCurrentPosition:init(x, y)
    _cachedTouchGoalPosition:init(goalX, goalY)
    _cachedTouchCurrentPosition:direction(_cachedTouchGoalPosition, _cachedTouchDirection)
    if _cachedTouchDirection:lengthSquared() > 0 then
        _cachedTouchDirection:normalize(_cachedTouchDirection)
    end

    local actualX, actualY = x, y
    if response.time >= 0 and response.time <= 1 and response.depth > 0 then
        actualX = x + response.offset.x
        actualY = y + response.offset.y
    elseif _cachedTouchDirection:dot(response.normal) >= 0 then
        actualX = goalX
        actualY = goalY
    end

    query:reset()

    return actualX, actualY, world:project(response.item, actualX, actualY, filter, query)
end

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc
--- @return number, number, slick.worldQueryResponse[], number, slick.worldQuery
local function cross(world, query, response, x, y, goalX, goalY, filter)
    return x, y, world:project(response.item, x, y, filter, query)
end

return {
    slide = slide,
    touch = touch,
    cross = cross
}
