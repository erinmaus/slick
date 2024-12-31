local point = require "slick.geometry.point"
local slickmath = require "slick.util.slickmath"

local _cachedSlideNormal = point.new()
local _cachedSlideCurrentPosition = point.new()
local _cachedSlideTouchPosition = point.new()
local _cachedOtherTouchPosition = point.new()
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
--- @return number, number, number, number
local function slide(world, query, response, x, y, goalX, goalY, filter)
    -- print("(slide) normal", response.normal.x, response.normal.y)
    -- print("(slide) xy", x, y)
    -- print("(slide) goal", goalX, goalY)

    -- if response:notTouchingWillTouch() then
    --     return x, y, world:project(response.item, x, y, x, y, query)
    -- end

    -- if response:isTouchingWillPenetrate() then
    --     return x, y, response.touch.x, response.touch.y
    -- end

    -- local touchX, touchY
    -- if response:isTouchingWillPenetrate() then
    --     touchX = x
    --     touchY = y
    -- else
    --     touchX = response.touch.x
    --     touchY = response.touch.y
    -- end

    if #query.results > 1 then
        local maxDistance = 0
        for _, result in ipairs(query.results) do
            _cachedOtherTouchPosition:init(result.touch.x, result.touch.y)

            print("(slide) touch-goal distance", _cachedOtherTouchPosition:distance(_cachedSlideTouchPosition), "min", world.options.minSlideDistance)
            maxDistance = math.max(maxDistance, _cachedOtherTouchPosition:distance(_cachedSlideTouchPosition))
        end

        print("(slide) max distance", maxDistance)
        
        if maxDistance < world.options.minSlideDistance then
            print("... not sliding ...")
            return response.touch.x, response.touch.y, response.touch.x, response.touch.y
        end
    end

    _cachedSlideCurrentPosition:init(x, y)
    _cachedSlideTouchPosition:init(response.touch.x, response.touch.y)
    _cachedSlideGoalPosition:init(goalX, goalY)

    _cachedSlideGoalPosition:direction(_cachedSlideTouchPosition, _cachedSlideGoalDirection)
    local dot = _cachedSlideGoalDirection:dot(response.normal)

    response.normal:multiplyScalar(dot, _cachedSlideNewGoalPosition)
    _cachedSlideNewGoalPosition:add(_cachedSlideGoalPosition, _cachedSlideNewGoalPosition)

    print("(slide) normal", response.normal.x, response.normal.y)

    -- _cachedSlideTouchPosition:init(touchX, touchY)
    -- _cachedSlideGoalPosition:init(goalX, goalY)
    -- _cachedSlideTouchPosition:direction(_cachedSlideGoalPosition, _cachedSlideGoalDirection)
    -- _cachedSlideGoalDirection:normalize(_cachedSlideGoalDirection)

    -- _cachedSlideNewGoalPosition:init(touchX, touchY)

    --_cachedSlideNormal:init(response.normal.x, response.normal.y)
    --_cachedSlideNormal
    --_cachedSlideNormal:left(_cachedSlideNormal)

    -- _cachedSlideTouchPosition:direction(_cachedSlideGoalPosition, _cachedSlideDirection)

    -- local dot = _cachedSlideDirection:dot(_cachedSlideNormal)
    -- _cachedSlideNormal:multiplyScalar(dot, _cachedSlideNewGoalPosition)
    -- _cachedSlideTouchPosition:add(_cachedSlideNewGoalPosition, _cachedSlideNewGoalPosition)
    
    local newGoalX, newGoalY = _cachedSlideNewGoalPosition.x, _cachedSlideNewGoalPosition.y

    gx, gy = newGoalX, newGoalY
    tx, ty = response.touch.x, response.touch.y

    --world:project(response.item, response.touch.x, response.touch.y, newGoalX, newGoalY, filter, query)

    return response.touch.x, response.touch.y, newGoalX, newGoalY
end

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @return number, number, number, number
local function touch(world, query, response, x, y, goalX, goalY)
    return x, y, response.touch.x, response.touch.y
end

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @return number, number, number, number
local function cross(world, query, response, x, y, goalX, goalY)
    return goalX, goalY, goalX, goalY
end

return {
    slide = slide,
    touch = touch,
    cross = cross
}
