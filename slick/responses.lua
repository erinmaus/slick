local point = require "slick.geometry.point"
local worldQuery = require "slick.worldQuery"

local _workingQueries = setmetatable({}, { __mode = "k" })

local function getWorkingQuery(world)
    local workingQuery = _workingQueries[world]
    if not _workingQueries[world] then
        workingQuery = worldQuery.new(world)
        _workingQueries[world] = workingQuery
    end

    return workingQuery
end

local _cachedSlideNormal = point.new()
local _cachedSlideCurrentPosition = point.new()
local _cachedSlideTouchPosition = point.new()
local _cachedSlideGoalPosition = point.new()
local _cachedSlideGoalDirection = point.new()
local _cachedSlideNewGoalPosition = point.new()
local _cachedSlideDirection = point.new()

local function trySlide(normalX, normalY, touchX, touchY, x, y, goalX, goalY)
    _cachedSlideCurrentPosition:init(x, y)
    _cachedSlideTouchPosition:init(touchX, touchY)
    _cachedSlideGoalPosition:init(goalX, goalY)

    _cachedSlideNormal:init(normalX, normalY)
    _cachedSlideNormal:left(_cachedSlideGoalDirection)

    _cachedSlideCurrentPosition:direction(_cachedSlideGoalPosition, _cachedSlideNewGoalPosition)
    _cachedSlideNewGoalPosition:normalize(_cachedSlideDirection)

    local goalDotDirection = _cachedSlideNewGoalPosition:dot(_cachedSlideGoalDirection)
    _cachedSlideGoalDirection:multiplyScalar(goalDotDirection, _cachedSlideGoalDirection)
    _cachedSlideTouchPosition:add(_cachedSlideGoalDirection, _cachedSlideNewGoalPosition)

    return _cachedSlideNewGoalPosition.x, _cachedSlideNewGoalPosition.y
end

--- @param world slick.world
--- @param response slick.worldQueryResponse
--- @param query slick.worldQuery
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
--- @return boolean
local function findDidSlide(world, response, query, x, y, goalX, goalY)
    if #query.results == 0 or query.results[1].time > 0 then
        return true
    end

    local didSlide = true
    for _, otherResponse in ipairs(query.results) do
        if otherResponse.time > 0 then
            didSlide = false
            break
        end

        local otherResponseName = world:respond(otherResponse, query, x, y, goalX, goalY, true)
        if (otherResponse.shape == response.shape and otherResponse.otherShape == response.otherShape) or otherResponseName == "slide" then
            didSlide = false
            break
        end
    end

    return didSlide
end

local function didMove(x, y, goalX, goalY)
    return not (x == goalX and y == goalY)
end

local _slideNormals = {}

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
    result:push(response)

    local touchX, touchY = response.touch.x, response.touch.y
    local newGoalX, newGoalY = goalX, goalY

    local index = query:getResponseIndex(response)
    local didSlide = false
    local q = getWorkingQuery(world)

    _slideNormals[1], _slideNormals[2] = response.normals, response.alternateNormals

    for _, normals in ipairs(_slideNormals) do
        for _, normal in ipairs(normals) do
            local workingGoalX, workingGoalY = trySlide(normal.x, normal.y, response.touch.x, response.touch.y, x, y, goalX, goalY)
            if didMove(response.touch.x, response.touch.y, workingGoalX, workingGoalY) then
                world:project(response.item, response.touch.x, response.touch.y, workingGoalX, workingGoalY, filter, q)
                didSlide = findDidSlide(world, response, q, response.touch.x, response.touch.y, workingGoalX, workingGoalY)

                if didSlide then
                    newGoalX = workingGoalX
                    newGoalY = workingGoalY
                    break
                end
            end
        end

        if didSlide then
            break
        end
    end

    if didSlide then
        for i = index + 1, #query.results do
            local otherResponse = query.results[i]
            if otherResponse.time > response.time then
                break
            end

            world:respond(otherResponse, query, touchX, touchY, newGoalX, newGoalY, false)
            result:push(otherResponse)
        end

        world:project(response.item, touchX, touchY, newGoalX, newGoalY, filter, query)
        return touchX, touchY, newGoalX, newGoalY, nil, query.results[1]
    else
        local nextResponse = query.results[index + 1]
        return touchX, touchY, goalX, goalY, nil, nextResponse
    end
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
    result:push(response)

    local touchX, touchY = response.touch.x, response.touch.y

    local index = query:getResponseIndex(response)
    local nextResponse = query.results[index + 1]
    return touchX, touchY, touchX, touchY, nil, nextResponse
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

    local index = query:getResponseIndex(response)
    local nextResponse = query.results[index + 1]

    if not nextResponse then
        return goalX, goalY, goalX, goalY, nil, nil
    end

    return nextResponse.touch.x, nextResponse.touch.y, goalX, goalY, nil, nextResponse
end

local _cachedBounceCurrentPosition = point.new()
local _cachedBounceTouchPosition = point.new()
local _cachedBounceGoalPosition = point.new()
local _cachedBounceNormal = point.new()
local _cachedBounceNewGoalPosition = point.new()
local _cachedBounceDirection = point.new()

--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param goalX number
--- @param goalY number
local function getBounceNormal(response, x, y, goalX, goalY)
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

    return _cachedBounceNormal
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
local function bounce(world, query, response, x, y, goalX, goalY, filter, result)
    local bounceNormal = getBounceNormal(response, x, y, goalX, goalY)

    local maxDistance = _cachedBounceCurrentPosition:distance(_cachedBounceGoalPosition)
    local currentDistance = _cachedBounceCurrentPosition:distance(_cachedBounceTouchPosition)
    local remainingDistance = maxDistance - currentDistance

    bounceNormal:multiplyScalar(remainingDistance, _cachedBounceNewGoalPosition)
    _cachedBounceNewGoalPosition:add(_cachedBounceTouchPosition, _cachedBounceNewGoalPosition)

    local newGoalX = _cachedBounceNewGoalPosition.x
    local newGoalY = _cachedBounceNewGoalPosition.y
    local touchX, touchY = response.touch.x, response.touch.y

    response.extra.bounceNormal = query:allocate(point, bounceNormal.x, bounceNormal.y)
    result:push(response, false)

    world:project(response.item, touchX, touchY, newGoalX, newGoalY, filter, query)
    return touchX, touchY, newGoalX, newGoalY, nil, query.results[1]
end

return {
    slide = slide,
    touch = touch,
    cross = cross,
    bounce = bounce
}
