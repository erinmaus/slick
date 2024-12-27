local slick = require("slick")

local GRAVITY_Y = 500
local PLAYER_SPEED = 250
local PLAYER_JUMP_VELOCITY = 600

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
    if not player.isJumping and love.keyboard.isDown("space") then
        player.isJumping = true
        player.jumpVelocityY = -PLAYER_JUMP_VELOCITY
    end

    local x = 0
    if love.keyboard.isDown("left") then
        x = x - 1
    end
    
    if love.keyboard.isDown("right") then
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
    player.x = actualX
    player.y = actualY

    for _, hit in ipairs(hits) do
        if player.isJumping then
            if hit.normal.y > 0 then
                player.jumpVelocityY = 0
            end
        end

        if hit.normal.y < 0 then
            player.isJumping = false
        end
    end
end

local function makeLevel(world)
    local level = { type = "level" }

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    world:add(level, slick.newTransform(), 
        slick.newShapeGroupShape(
            slick.newPolylineShape({
                { 4, 4, 4, h / 2 },
                { 4, h / 2, w / 4, h - 4 },
                { w / 4, h - 4, w - 4, h - 4 },
                { w - 4, h - 4, w - 4, 4  }
            }),

            slick.newBoxShape(w / 2 + w / 4, h - 200, w / 8, 16)
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

function love.update(deltaTime)
    movePlayer(player, world, deltaTime)
end

function love.draw()
    slick.drawWorld(world)
end
