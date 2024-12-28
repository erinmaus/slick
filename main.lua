local slick = require("slick")

local GRAVITY_Y = 800
local PLAYER_SPEED = 250
local PLAYER_JUMP_VELOCITY = 800

local function makePlayer(world)
    local player = {
        type = "player",

        x = love.graphics.getWidth() / 2,
        y = love.graphics.getHeight() / 2,
        
        jumpVelocityY = 0,
        isJumping = true
    }

    world:add(player, player.x, player.y, slick.newBoxShape(0, 0, 32, 32))

    return player
end

local function movePlayer(player, world, deltaTime)
    deltaTime = 1 / 30

    local jumped = false
    if not player.isJumping and love.keyboard.isDown("w") then
        jumped = true
        player.isJumping = true
        player.jumpVelocityY = -PLAYER_JUMP_VELOCITY
    end

    local x = 0
    if love.keyboard.isDown("a") then
        x = x - 1
    end
    
    if love.keyboard.isDown("d") then
        x = x + 1
    end

    local goalY
    if player.isJumping then
        player.jumpVelocityY = player.jumpVelocityY + GRAVITY_Y * deltaTime
        goalY = player.y + player.jumpVelocityY * deltaTime
    else
        goalY = player.y + GRAVITY_Y * deltaTime
    end

    local goalX = player.x + x * PLAYER_JUMP_VELOCITY * deltaTime
    local actualX, actualY, hits = world:move(player, goalX, goalY, function() return "touch" end)

    if actualX ~= player.x or actualY ~= player.y then
        player.x = actualX
        player.y = actualY
    end

    for _, hit in ipairs(hits) do
        if player.isJumping then
            if hit.normal.y > 0 then
                player.jumpVelocityY = 0
            end
        end

        if hit.normal.y < 0 and not jumped then
            player.isJumping = false
        end
    end
end

local function makeLevel(world)
    local level = { type = "level" }

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    world:add(level, slick.newTransform(), 
        slick.newShapeGroup(
            slick.newBoxShape(0, 0, 8, h),
            slick.newBoxShape(w - 8, 0, 8, h),
            slick.newBoxShape(0, h - 8, w, 8),
            --slick.newPolygonShape({ 8, h / 2, w / 4, h - 8, 8, 8 }),
            slick.newBoxShape(w / 2 + w / 4, h - 150, w / 8, 60)
        )
    )

    return level
end

local world, player
function love.load()
    world = slick.newWorld(love.graphics.getWidth(), love.graphics.getHeight())
    makeLevel(world)

    player = makePlayer(world)
end

function love.mousepressed(x, y, button)
    if button == 1 then
        player.x, player.y = x - 16, y - 16
        world:update(player, player.x, player.y)
    end
end

function love.update(deltaTime)
    movePlayer(player, world, deltaTime)
end

function love.draw()
    slick.drawWorld(world, {
        { shape = slick.geometry.rectangle.new(player.x, player.y, player.x + 32, player.y + 32) }
    })
end
