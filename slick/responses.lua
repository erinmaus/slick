local point = require "slick.geometry.point"

local _cachedSlideNormal = point.new()
local _cachedSlideCurrentPosition = point.new()
local _cachedSlideGoalPosition = point.new()
local _cachedSlideGoalDirection = point.new()
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
    local actualX, actualY

    _cachedSlideCurrentPosition:init(x, y)
    _cachedSlideGoalPosition:init(goalX, goalY)
    _cachedSlideCurrentPosition:direction(_cachedSlideGoalPosition, _cachedSlideGoalDirection)
    _cachedSlideGoalDirection:normalize(_cachedSlideGoalDirection)

    local directionDotNormal = _cachedSlideGoalDirection:dot(response.normal)
    if response.time >= 0 and response.time <= 1 and directionDotNormal < 0 then
        actualX = x + response.offset.x
        actualY = y + response.offset.y
    else
        actualX = goalX
        actualY = goalY
    end

    if response.time < world.options.epsilon then
        _cachedSlideActualPosition:init(actualX, actualY)

        _cachedSlideNormal:init(response.normal.x, response.normal.y)
        _cachedSlideNormal:left(_cachedSlideNormal)

        _cachedSlideActualPosition:direction(_cachedSlideGoalPosition, _cachedSlideDirection)

        local dot = _cachedSlideDirection:dot(_cachedSlideNormal)
        _cachedSlideNormal:multiplyScalar(dot, _cachedSlideNormal)
        _cachedSlideNormal:add(_cachedSlideActualPosition, _cachedSlideActualPosition)

        actualX = _cachedSlideActualPosition.x
        actualY = _cachedSlideActualPosition.y
    end

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
    _cachedTouchDirection:normalize(_cachedTouchDirection)

    local actualX, actualY = x, y
    if response.time >= 0 and response.time <= 1 and response.depth > 0 then
        actualX = x + response.offset.x
        actualY = y + response.offset.y
    elseif _cachedTouchDirection:dot(response.normal) > 0 then
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
