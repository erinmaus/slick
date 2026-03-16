local slick = require("slick")
local test = require("test.common.test")

test("should cross everything in path", function(t)
    local world = slick.newWorld(800, 600)

    local player = { x = 400, y = 300 }
    world:add(player, player.x, player.y, slick.newCircleShape(0, 0, 20))

    local a = {}
    world:add(a, 500, 290, slick.newCircleShape(0, 0, 20))
    local b = {}
    world:add(b, 550, 310, slick.newCircleShape(0, 0, 20))

    local collisions
    player.x, player.y, collisions = world:move(player, 600, 300, function() return "cross" end)

    assert(player.x == 600 and player.y == 300, "player should not have been stopped")
    assert(#collisions == 2, "should have two collisions (one with a and one with b)")
    assert(collisions[1].other == a, "should have collided with a first")
    assert(collisions[2].other == b, "should have collided with b second")
end)
