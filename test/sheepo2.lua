local slick = require("slick")
local test = require("test.common.test")
local util = require("test.common.util")

test("should handle cross & slide interactions", function(t)
    local world = slick.newWorld(800, 600)

    local a = { x = 0, y = 100, width = 50, height = 50 }
    local b = { x = 300, y = 75, width = 200, height = 250 }
    local c = { x = 250, y = 150, width = 50, height = 100, cross = true }

    world:add(a, a.x, a.y, slick.newRectangleShape(0, 0, a.width, a.height))
    world:add(b, b.x, b.y, slick.newRectangleShape(0, 0, b.width, b.height))
    world:add(c, c.x, c.y, slick.newRectangleShape(0, 0, c.width, c.height))

    local collisions = t:moveUntilCollision(function(delta)
        local c
        a.x, a.y, c = world:move(a, a.x + 200 * delta, a.y)
        return c
    end)

    assert(#collisions == 1, "expected one collisions")
    assert(collisions[1].other == b, "expected collision with b")
    assert(collisions[1].normal.x == -1 and collisions[1].normal.y == 0, "normal for first collision should be equal to (-1, 0)")
    assert(collisions[1].alternateNormal.x == 1 and collisions[1].alternateNormal.y == 0, "alt normal for first collision should be equal to (1, 0)")

    collisions = t:moveUntilCollision(function(delta)
        local c
        a.x, a.y, c = world:move(a, a.x + 200 * delta, a.y + 200 * delta, function(item, other) return other.cross and "cross" or "slide" end)
        return c
    end)

    assert(#collisions == 3, "expected three collisions")
    assert((collisions[1].response == "cross" and collisions[2].response == "slide") or (collisions[1].response == "slide" and collisions[2].response == "cross"), "first response should be cross or slide, and second the opposite")
    assert((collisions[1].response == "cross" and collisions[1].other == c) or (collisions[2].response == "cross" and collisions[2].other == c), "first cross collision should be with c")
    assert((collisions[1].response == "slide" and collisions[1].other == b) or (collisions[2].response == "slide" and collisions[2].other == b), "first slide collision should be with b")
    assert(collisions[3].response == "cross", "third response should be cross")
    assert(collisions[3].other == c, "third collision should be with c")

    collisions = t:moveUntilCollision(function(delta)
        local c
        a.x, a.y, c = world:move(a, a.x, a.y + 200 * delta, function(item, other) return other.cross and "cross" or "slide" end)
        return c
    end)

    assert(#collisions == 1)
    assert(collisions[1].response == "cross", "expected cross")
    assert(collisions[1].other == c, "expected collision with c")

    collisions = t:moveUntilCollision(function(delta)
        local c
        a.x, a.y, c = world:move(a, a.x, a.y + 200 * delta, function(item, other) return other.cross and "cross" or "slide" end)
        return c
    end, 0)

    assert(a.y >= 250, "a should be below c")
end)