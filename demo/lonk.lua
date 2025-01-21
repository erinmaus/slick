local slick = require("slick")
local common = require("demo.common")

local PLAYER_SPEED = 350

local demo = {
    world = slick.newWorld(1000, 1000, {
        quadTreeX = 0,
        quadTreeY = 0
    })
}

local function makePlayer()
    local player = {
        type = "player",

        x = 200,
        y = 500,

        jumpYVelocity = 0,

        radius = 16
    }

    demo.world:add(player, player.x, player.y, slick.newCircleShape(0, 0, player.radius))

    return player
end

local function getPlayerInput()
    local x = 0

    if love.keyboard.isDown("a", "left") then
        x = x - 1
    end

    if love.keyboard.isDown("d", "right") then
        x = x + 1
    end

    local y = 0

    if love.keyboard.isDown("w", "up") then
        y = y - 1
    end

    if love.keyboard.isDown("s", "down") then
        y = y + 1
    end

    local length = math.sqrt(x ^ 2 + y ^ 2)
    if length > 0 then
        x = x / length
        y = y / length
    end

    return x, y
end

local function updatePlayer(player, deltaTime)
    local inputX, inputY = getPlayerInput()

    local goalX = player.x + inputX * PLAYER_SPEED * deltaTime
    local goalY = player.y + inputY * PLAYER_SPEED * deltaTime

    player.x, player.y = demo.world:move(player, goalX, goalY)
end

local function makeLevel()
    local level = { type = "level" }

    demo.world:add(level, 0, 0, slick.newShapeGroup(
        slick.newRectangleShape(0, 0, 1000, 100),
        slick.newRectangleShape(0, 900, 1000, 100),
        slick.newRectangleShape(0, 100, 100, 800),
        slick.newRectangleShape(900, 100, 100, 800),
        slick.newPolygonShape({
            100, 100,
            250, 100,
            100, 250
        }),
        slick.newPolygonShape({
            750, 100,
            900, 100,
            900, 250
        })
    ))

    return level
end

local function makeRectangle(x, y, w, h, rotation)
    local level = { type = "level" }
    demo.world:add(
        level,
        slick.newTransform(x, y, rotation),
        slick.newRectangleShape(-w / 2, -h / 2, w, h, slick.newTag("cross"))
    )

    return level
end

demo.player = makePlayer()
demo.level = makeLevel()

demo.gears = {
    common.makeGear(demo.world, 250, 250, common.makeGearShape(50, 40)),
    common.makeGear(demo.world, 500, 500, common.makeGearShape(nil, nil, nil, nil, 10)),
    common.makeGear(demo.world, 725, 725, common.makeGearShape()),
}

demo.rectangles = {
    makeRectangle(350, 575, 120, 30, math.pi / 4)
}

function demo.update(deltaTime)
    for _, gear in ipairs(demo.gears) do
        common.updateGear(gear, demo.world, -deltaTime)
    end

    updatePlayer(demo.player, deltaTime)
end

function demo.draw()
    love.graphics.push()

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.translate(-demo.player.x, -demo.player.y)
    love.graphics.translate(w / 2, h / 2)

    slick.drawWorld(demo.world)
    love.graphics.pop()
end

local help = [[
lönk player controls

- w, a, s, d: move
- left, right, up, down: move (alternative)
]]

function demo.help()
    love.graphics.print(help, 8, 8)
end

return demo