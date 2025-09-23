local slick = require("slick")
local test = require("test.common.test")

test("should collide with two blocks from above", function(t)
    local world = slick.newWorld(800, 600)

    local a = { x = 125, y = 50, width = 50, height = 50, vel = 0 }
    local b = { x = 200, y = 100 }
    local c = { x = 100, y = 100 }
    local d = { x = 150, y = 100 }
    local e = { x = 50, y = 100 }

    world:add(a, a.x, a.y, slick.newRectangleShape(0, 0, a.width, a.height))
    world:add(b, b.x, b.y, slick.newRectangleShape(0, 0, 50, 50))
    world:add(c, c.x, c.y, slick.newRectangleShape(0, 0, 50, 50))
    world:add(d, d.x, d.y, slick.newRectangleShape(0, 0, 50, 50))
    world:add(e, e.x, e.y, slick.newRectangleShape(0, 0, 50, 50))

    local collisions = t:moveUntilCollision(function(delta)
        local c
        a.vel = a.vel + 1000 * delta
        a.x, a.y, c = world:move(a, a.x, a.y + a.vel * delta)
        return c
    end)

    assert(#collisions == 2, "expected two collisions")
    assert((collisions[1].other == c and collisions[2].other == d) or (collisions[1].other == d and collisions[2].other == c), "expected collision with 'd' and 'c'")
    assert(collisions[1].normal.x == 0 and collisions[1].normal.y == -1, "normal for first collision should be equal to (0, -1)")
    assert(collisions[1].alternateNormal.x == 0 and collisions[1].alternateNormal.y == 1, "alt normal for first collision should be equal to (0, 1)")
    assert(collisions[2].normal.x == 0 and collisions[2].normal.y == -1, "normal for second should be equal to (0, -1)")
    assert(collisions[2].alternateNormal.x == 0 and collisions[2].alternateNormal.y == 1, "alt normal for second collision should be equal to (0, 1)")
end)

test("should collide with two blocks from below", function(t)
    local world = slick.newWorld(800, 600)

    local a = { x = 125, y = 200, width = 50, height = 50, vel = 0 }
    local b = { x = 200, y = 100 }
    local c = { x = 100, y = 100 }
    local d = { x = 150, y = 100 }
    local e = { x = 50, y = 100 }

    world:add(a, a.x, a.y, slick.newRectangleShape(0, 0, a.width, a.height))
    world:add(b, b.x, b.y, slick.newRectangleShape(0, 0, 50, 50))
    world:add(c, c.x, c.y, slick.newRectangleShape(0, 0, 50, 50))
    world:add(d, d.x, d.y, slick.newRectangleShape(0, 0, 50, 50))
    world:add(e, e.x, e.y, slick.newRectangleShape(0, 0, 50, 50))

    local collisions = t:moveUntilCollision(function(delta)
        local c
        a.vel = a.vel - 1000 * delta
        a.x, a.y, c = world:move(a, a.x, a.y + a.vel * delta)
        return c
    end)

    assert(#collisions == 2, "expected two collisions")
    assert((collisions[1].other == c and collisions[2].other == d) or (collisions[1].other == d and collisions[2].other == c), "expected collision with 'd' and 'c'")
    assert(collisions[1].normal.x == 0 and collisions[1].normal.y == 1, "normal for first collision should be equal to (0, 1)")
    assert(collisions[1].alternateNormal.x == 0 and collisions[1].alternateNormal.y == -1, "alt normal for first collision should be equal to (0, -1)")
    assert(collisions[2].normal.x == 0 and collisions[2].normal.y == 1, "normal for second should be equal to (0, 1)")
    assert(collisions[2].alternateNormal.x == 0 and collisions[2].alternateNormal.y == -1, "alt normal for second collision should be equal to (0, -1)")
end)
