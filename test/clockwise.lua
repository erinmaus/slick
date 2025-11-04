local slick = require("slick")
local test = require("test.common.test")
local util = require("test.common.util")

test("polygons should be clockwise even if input is counter-clockwise", function(t)
    local world = slick.newWorld(800, 600)

    local a = { x = 100, y = 100 }
    local b = {
        x = 100,
        y = 250
    }

    local SPEED = 100

    -- This input for newPolygonShape is counterclockwise.
    -- It should produce a clockwise-orientated shape.
    world:add(a, a.x, a.y, slick.newPolygonShape({
        0, 0,
        0, 100,
        100, 100,
        100, 0
    }))
    world:add(b, b.x, b.y, slick.newCircleShape(0, 0, 16))

    t:moveUntilCollision(function(delta)
        local c
        b.x, b.y, c = world:move(b, b.x, b.y - SPEED * delta)
        return c
    end)

    t:moveForOneFrame(function(delta)
        local c
        b.x, b.y, c = world:move(b, b.x, b.y - SPEED * delta)
        return c
    end)

    local finalX, finalY, lastDelta
    local collisions = t:moveForOneFrame(function(delta)
        lastDelta = delta

        local x, y, c = world:move(b, b.x - SPEED * delta, b.y)
        finalX, finalY = x, y

        return c
    end)


    assert(#collisions == 0, "expected no collision")
    assert(not (util.equalish(finalX, b.x, lastDelta) and util.equalish(finalY, b.y, lastDelta)), "expect shape to move more than 1 pixel per second")
end)

test("polygons should be clockwise even if input is clockwise", function(t)
    local world = slick.newWorld(800, 600)

    local a = { x = 100, y = 100 }
    local b = {
        x = 100,
        y = 250
    }

    local SPEED = 100

    -- This input for newPolygonShape is clockwise.
    -- So everything should be fine.
    world:add(a, a.x, a.y, slick.newPolygonShape({
        100, 0,
        100, 100,
        0, 100,
        0, 0
    }))
    world:add(b, b.x, b.y, slick.newCircleShape(0, 0, 16))

    t:moveUntilCollision(function(delta)
        local c
        b.x, b.y, c = world:move(b, b.x, b.y - SPEED * delta)
        return c
    end)

    t:moveForOneFrame(function(delta)
        local c
        b.x, b.y, c = world:move(b, b.x, b.y - SPEED * delta)
        return c
    end)

    local finalX, finalY, lastDelta
    local collisions = t:moveForOneFrame(function(delta)
        lastDelta = delta

        local x, y, c = world:move(b, b.x - SPEED * delta, b.y)
        finalX, finalY = x, y

        return c
    end)


    assert(#collisions == 0, "expected no collision")
    assert(not (util.equalish(finalX, b.x, lastDelta) and util.equalish(finalY, b.y, lastDelta)), "expect shape to move more than 1 pixel per second")
end)
