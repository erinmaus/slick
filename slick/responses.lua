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
--- @param result slick.worldQuery
--- @return number, number, number, number, string?, slick.worldQueryResponse?
local function slide(world, query, response, x, y, goalX, goalY, filter, result)
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
    
    result:push(response)
    world:project(response.item, touchX, touchY, newGoalX, newGoalY, filter, query)
    return touchX, touchY, newGoalX, newGoalY, "touch", nil
end

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc
--- @param result slick.worldQuery
--- @return number, number, number, number, string?, slick.worldQueryResponse?
local function touch(world, query, response, x, y, goalX, goalY, filter, result)
    local touchX, touchY = response.touch.x, response.touch.y
    
    result:push(response)
    world:project(response.item, x, y, response.touch.x, response.touch.y, filter, query)
    
    return touchX, touchY, touchX, touchY, nil, nil
end

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc
--- @param result slick.worldQuery
--- @return number, number, number, number, string?, slick.worldQueryResponse?
local function cross(world, query, response, x, y, goalX, goalY, filter, result)
    result:push(response)

    local index = 1
    local nextResponseName
    for i = 2, #query.results do
        local otherResponse = query.results[i]

        if type(otherResponse.response) == "function" or type(otherResponse.response) == "table" then
            nextResponseName = otherResponse.response(otherResponse.item, world, query, otherResponse, x, y, goalX, goalY)
        elseif type(otherResponse.response) == "string" then
            --- @diagnostic disable-next-line: cast-local-type
            nextResponseName = otherResponse.response
        else
            nextResponseName = "slide"
        end

        otherResponse.response = nextResponseName

        if nextResponseName == "cross" then
            result:push(otherResponse)
            index = i
        else
            break
        end
    end

    if index == #query.results or #query.results == 0 then
        world:project(response.item, x, y, goalX, goalY, filter, query)
        return goalX, goalY, goalX, goalY, nil, nil
    end

    local nextResponse = query.results[index + 1]
    return nextResponse.touch.x, nextResponse.touch.y, goalX, goalY, nil, nextResponse
end

local _cachedBounceCurrentPosition = point.new()
local _cachedBounceTouchPosition = point.new()
local _cachedBounceGoalPosition = point.new()
local _cachedBounceNormal = point.new()
local _cachedBounceGoalDirection = point.new()
local _cachedBounceNewGoalPosition = point.new()
local _cachedBounceDirection = point.new()

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @param filter slick.worldFilterQueryFunc
--- @param result slick.worldQuery
--- @return number, number, number, number, string?, slick.worldQueryResponse?
local function bounce(world, query, response, x, y, goalX, goalY, filter, result)
    _cachedBounceCurrentPosition:init(x, y)
    _cachedBounceTouchPosition:init(response.touch.x, response.touch.y)
    _cachedBounceGoalPosition:init(goalX, goalY)

    _cachedBounceCurrentPosition:direction(_cachedBounceGoalPosition, _cachedBounceDirection)
    _cachedBounceDirection:normalize(_cachedBounceDirection)

    local bounceNormalDot = 2 * response.normal:dot(_cachedBounceDirection)
    response.normal:multiplyScalar(bounceNormalDot, _cachedBounceNormal)
    _cachedBounceDirection:sub(_cachedBounceNormal, _cachedBounceNormal)
    _cachedBounceNormal:normalize(_cachedBounceNormal)

    if _cachedBounceNormal:lengthSquared() == 0 then
        response.normal:negate(_cachedBounceNormal)
    end

    local maxDistance = _cachedBounceCurrentPosition:distance(_cachedBounceGoalPosition)
    local currentDistance = _cachedBounceCurrentPosition:distance(_cachedBounceTouchPosition)
    local remainingDistance = maxDistance - currentDistance

    _cachedBounceNormal:multiplyScalar(remainingDistance, _cachedBounceNewGoalPosition)
    _cachedBounceNewGoalPosition:add(_cachedBounceTouchPosition, _cachedBounceNewGoalPosition)

    local newGoalX = _cachedBounceNewGoalPosition.x
    local newGoalY = _cachedBounceNewGoalPosition.y
    local touchX, touchY = response.touch.x, response.touch.y

    response.extra.bounceNormal = query:allocate(point, _cachedBounceNormal.x, _cachedBounceNormal.y)
    result:push(response)

    world:project(response.item, touchX, touchY, newGoalX, newGoalY, filter, query)
    return touchX, touchY, newGoalX, newGoalY
end

return {
    slide = slide,
    touch = touch,
    cross = cross,
    bounce = bounce
}
