local point = require "slick.geometry.point"

local _cachedSlideCurrentPosition = point.new()
local _cachedSlideTouchPosition = point.new()
local _cachedSlideGoalPosition = point.new()
local _cachedSlideGoalDirection = point.new()
local _cachedSlideNewGoalPosition = point.new()
local _cachedSlideDirection = point.new()

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc
--- @return number, number, number, number, string?
local function slide(world, query, response, x, y, goalX, goalY, filter)
    _cachedSlideCurrentPosition:init(x, y)
    _cachedSlideTouchPosition:init(response.touch.x, response.touch.y)
    _cachedSlideGoalPosition:init(goalX, goalY)

    response.normal:left(_cachedSlideGoalDirection)

    _cachedSlideCurrentPosition:direction(_cachedSlideGoalPosition, _cachedSlideNewGoalPosition)
    _cachedSlideNewGoalPosition:normalize(_cachedSlideDirection)

    local goalDotDirection = _cachedSlideNewGoalPosition:dot(_cachedSlideGoalDirection)
    _cachedSlideGoalDirection:multiplyScalar(goalDotDirection, _cachedSlideGoalDirection)
    _cachedSlideTouchPosition:add(_cachedSlideGoalDirection, _cachedSlideNewGoalPosition)

    local newGoalX = _cachedSlideNewGoalPosition.x
    local newGoalY = _cachedSlideNewGoalPosition.y
    local touchX, touchY = response.touch.x, response.touch.y

    world:project(response.item, touchX, touchY, newGoalX, newGoalY, filter, query)
    return touchX, touchY, newGoalX, newGoalY, "touch"
end

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc
--- @return number, number, number, number, string?
local function touch(world, query, response, x, y, goalX, goalY, filter)
    local touchX, touchY = response.touch.x, response.touch.y
    world:project(response.item, x, y, response.touch.x, response.touch.y, filter, query)

    return touchX, touchY, touchX, touchY, nil
end

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc
--- @return number, number, number, number, string?
local function cross(world, query, response, x, y, goalX, goalY, filter)
    world:project(response.item, x, y, goalX, goalY, filter, query)
    return goalX, goalY, goalX, goalY, nil
end

return {
    slide = slide,
    touch = touch,
    cross = cross
}
