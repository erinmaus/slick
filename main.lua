if love.system.getOS() == "OS X" and jit and jit.arch == "arm64" then
    jit.off()
end

local slick = require("slick")

local GRAVITY_Y = 1200
local PLAYER_SPEED = 500
local PLAYER_JUMP_VELOCITY = 800

local function makePlayer(world)
    local player = {
        type = "player",

        x = love.graphics.getWidth() / 2,
        y = love.graphics.getHeight() / 2,
        w = 32,
        h = 32,
        
        jumpVelocityY = 0,
        isJumping = false
    }

    world:add(player, player.x, player.y, slick.newBoxShape(0, 0, player.w, player.h))

    return player
end

local function movePlayer(player, world, deltaTime)
    --deltaTime = 1 / 240

    --- @cast world slick.world
    local hits = world:queryRectangle(player.x, player.y + player.h, player.w, 2, function(item)
        return item ~= player
    end)

    local isInAir = true
    for i = 1, #hits do
        if hits[i].normal.y < 0 then
            isInAir = false
        end
    end
    
    if not isInAir and love.keyboard.isDown("w") then
        player.isJumping = true
        player.jumpVelocityY = -PLAYER_JUMP_VELOCITY
        isInAir = true
    end

    local x = 0
    if love.keyboard.isDown("a") then
        x = x - 1
    end
    
    if love.keyboard.isDown("d") then
        x = x + 1
    end

    local goalY
    if isInAir then
        player.jumpVelocityY = player.jumpVelocityY + GRAVITY_Y * deltaTime
        if player.isJumping then
            goalY = player.y + player.jumpVelocityY * deltaTime
        else
            goalY = player.y + GRAVITY_Y * deltaTime
        end
    else
        if player.isJumping then
            player.isJumping = false
        end

        goalY = player.y
    end

    local goalX = player.x + x * PLAYER_SPEED * deltaTime
    local actualX, actualY, hits = world:move(player, goalX, goalY)

    player.x, player.y = actualX, actualY

    for _, hit in ipairs(hits) do
        if player.isJumping then
            if hit.normal.y > 0 then
                player.jumpVelocityY = 0
            end
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
            slick.newPolygonShape({ 8, h - h / 8, w / 4, h - 8, 8, h - 8 }),
            slick.newPolygonShape({ w - w / 4, h, w - 8, h / 2, w - 8, h }),
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

local time = 0
function love.update(deltaTime)
    local b = love.timer.getTime()
    movePlayer(player, world, deltaTime)
    local a = love.timer.getTime()
    time = (a - b) * 1000
end

function love.draw()
    love.graphics.printf(string.format("Logic: %2.2f ms", time), 0, 0, love.graphics.getWidth(), "center")

    slick.drawWorld(world, {
        --{ shape = slick.geometry.rectangle.new(player.x, player.y, player.x + 32, player.y + 32) }
    })
end
