local slick = require "slick"
local common = {}

function common.makeGearShape(innerRadius, outerRadius, innerTaper, outerTaper, notches)
    -- Borrowed from here: https://stackoverflow.com/a/23532468

    innerRadius = innerRadius or 128
    outerRadius = outerRadius or 96
    innerTaper = innerTaper or 0.5
    outerTaper = outerTaper or 0.3
    notches = notches or 5

    local angle = math.pi * 2 / (notches * 2)
    local innerT = angle * (innerTaper / 2)
    local outerT = angle * (outerTaper / 2)
    local toggle = false

    local points = {}
    for a = angle, math.pi * 2, angle do
        if toggle then
            table.insert(points, innerRadius * math.cos(a - innerT))
            table.insert(points, innerRadius * math.sin(a - innerT))

            table.insert(points, outerRadius * math.cos(a + outerT))
            table.insert(points, outerRadius * math.sin(a + outerT))
        else
            table.insert(points, outerRadius * math.cos(a - outerT))
            table.insert(points, outerRadius * math.sin(a - outerT))

            table.insert(points, innerRadius * math.cos(a + innerT))
            table.insert(points, innerRadius * math.sin(a + innerT))
        end

        toggle = not toggle
    end

    return slick.newPolygonMeshShape(points)
end

--- @param world slick.world
--- @param x number
--- @param y number
function common.makeGear(world, x, y, shape)
    local gear = {
        angle = love.math.random() * math.pi * 2,
        angularVelocity = (love.math.random() * 0.5 + 0.5) * math.pi / 4,
        x = x,
        y = y
    }

    world:add(gear, x, y, shape)

    return gear
end

local function thingPushFilter(item)
    return item.type == "player"
end

local function notLevelRotateFilter(item)
    return not (item.type == "level" or item.type == "gear")
end

--- @param gear any
--- @param world slick.world
--- @param deltaTime number
function common.updateGear(gear, world, deltaTime)
    gear.angle = gear.angle + gear.angularVelocity * deltaTime
    world:rotate(gear, gear.angle, notLevelRotateFilter, thingPushFilter)
end

return common
