local slick = require("slick")
local test = require("test.common.test")

test("should slide up along axis aligned boxes", function(t)
    local world = slick.newWorld(200, 200)

    local function newBlock(x, y)
        local b = {}
        b.x = x
        b.y = y
        local shape = slick.newRectangleShape(0, 0, 1, 1)
        world:add(b, x, y, shape)
        return b
    end

    local blocks = {}
    for i = -3, 2 do
        table.insert(blocks, newBlock(0, i))
        table.insert(blocks, newBlock(1, i))
    end

    local player = {}
    player.x = -2
    player.y = 0
    player.w = 1
    player.h = 1
    player.shape = slick.newRectangleShape(0, 0, player.w, player.h)
    world:add(player, player.x, player.y, player.shape)

    t:moveUntilCollision(function(delta)
        local c
        player.x, player.y, c = world:move(player, player.x + 10 * delta, player.y)
        return c
    end)

    local oldX, oldY = player.x, player.y
    player.x, player.y = world:move(player, player.x + 0.01, player.y + 0.01)

    assert(player.y > oldY, "player should have slid up")
    assert(math.abs(player.x - oldX) < world.options.epsilon, "player should have slid down, not moved right (within epsilon)")
end)

test("should slide down along axis aligned boxes", function(t)
    local world = slick.newWorld(200, 200)

    local function newBlock(x, y)
        local b = {}
        b.x = x
        b.y = y
        local shape = slick.newRectangleShape(0, 0, 1, 1)
        world:add(b, x, y, shape)
        return b
    end

    local blocks = {}
    for i = -3, 2 do
        table.insert(blocks, newBlock(0, i))
        table.insert(blocks, newBlock(1, i))
    end

    local player = {}
    player.x = -2
    player.y = 0
    player.w = 0.6
    player.h = 0.6
    player.shape = slick.newRectangleShape(0, 0, player.w, player.h)
    world:add(player, player.x, player.y, player.shape)

    t:moveUntilCollision(function(delta)
        local c
        player.x, player.y, c = world:move(player, player.x + 10 * delta, player.y)
        return c
    end)

    local oldX, oldY = player.x, player.y
    player.x, player.y = world:move(player, player.x + 0.01, player.y - 0.01)

    assert(player.y < oldY, "player should have slid down")
    assert(math.abs(player.x - oldX) < world.options.epsilon, "player should have slid down, not moved right (within epsilon)")
end)
