local slick = require("slick")
local test = require("test.common.test")
local util = require("test.common.util")

test("should handle contact points when self vertices don't touch other edge", function(t)
    local world = slick.newWorld(800, 600)

    local a = { x = 0, y = -100, width = 100, height = 250 }
    local b = { x = 300, y = 0, width = 100, height = 50 }

    world:add(a, a.x, a.y, slick.newRectangleShape(0, 0, a.width, a.height))
    world:add(b, b.x, b.y, slick.newRectangleShape(0, 0, b.width, b.height))

    local collisions = t:moveUntilCollision(function(delta)
        local c
        a.x, a.y, c = world:move(a, a.x + 200 * delta, a.y)
        return c
    end)
    
    assert(#collisions == 1, "expected one collisions")
    assert(util.hasPoint(collisions[1].contactPoints, 300, 50), "expected point (300, 50) as contact point (from b)")
    assert(util.hasPoint(collisions[1].contactPoints, 300, 0), "expected point (300, 50) as contact point (from b)")
    assert(util.hasPoint(collisions[1].contactPoints, collisions[1].contactPoint.x, collisions[1].contactPoint.y), "expected contact point in contact points")
end)

test("should handle contact points when self vertices touch other edge", function(t)
    local world = slick.newWorld(800, 600)

    local a = { x = 0, y = 100, width = 100, height = 50 }
    local b = { x = 300, y = 0, width = 100, height = 250 }

    world:add(a, a.x, a.y, slick.newRectangleShape(0, 0, a.width, a.height))
    world:add(b, b.x, b.y, slick.newRectangleShape(0, 0, b.width, b.height))

    local collisions = t:moveUntilCollision(function(delta)
        local c
        a.x, a.y, c = world:move(a, a.x + 200 * delta, a.y)
        return c
    end)

    assert(#collisions == 1, "expected one collisions")
    assert(util.hasPoint(collisions[1].contactPoints, 300, 250), "expected point (300, 250) as contact point (from a)")
    assert(util.hasPoint(collisions[1].contactPoints, 300, 0), "expected point (300, 0) as contact point (from a)")
    assert(util.hasPoint(collisions[1].contactPoints, collisions[1].contactPoint.x, collisions[1].contactPoint.y), "expected contact point in contact points")
end)

test("should handle contact points when self vertices are collinear with other vertices", function(t)
    local world = slick.newWorld(800, 600)

    local a = { x = 0, y = 0, width = 100, height = 50 }
    local b = { x = 300, y = 0, width = 100, height = 50 }

    world:add(a, a.x, a.y, slick.newRectangleShape(0, 0, a.width, a.height))
    world:add(b, b.x, b.y, slick.newRectangleShape(0, 0, b.width, b.height))

    local collisions = t:moveUntilCollision(function(delta)
        local c
        a.x, a.y, c = world:move(a, a.x + 200 * delta, a.y)
        return c
    end)

    assert(#collisions == 1, "expected one collisions")
    assert(#collisions[1].contactPoints == 2, "expected two contact points")
    assert(util.hasPoint(collisions[1].contactPoints, 300, 50), "expected point (300, 250) as contact point (from a)")
    assert(util.hasPoint(collisions[1].contactPoints, 300, 0), "expected point (300, 0) as contact point (from a)")
    assert(util.hasPoint(collisions[1].contactPoints, collisions[1].contactPoint.x, collisions[1].contactPoint.y), "expected contact point in contact points")
end)
