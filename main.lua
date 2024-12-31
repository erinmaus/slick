if love.system.getOS() == "OS X" and jit and jit.arch == "arm64" then
    jit.off()
end

local slick = require("slick")

local GRAVITY_Y = 1200
local PLAYER_SPEED = 500
local PLAYER_JUMP_VELOCITY = 800
local isGravityEnabled = false
local query

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
    --- @cast world slick.world
    
    local isInAir = true
    if isGravityEnabled then
        world:queryRectangle(player.x, player.y + player.h, player.w, 1, function(item)
            return item ~= player
        end, query)

        for _, result in ipairs(query.results) do
            if result.normal.y > 0 then
                isInAir = false
            end
        end
    end
    
    local groundNormal = slick.geometry.point.new(0, 0)
    if not isInAir then
        world:queryRay(player.x + player.w / 2, player.y + player.h, 0, 1, function(item)
            return item ~= player
        end, query)

        if #query.results >= 1 then
            --groundNormal:init(query.results[1].normal.x, query.results[1].normal.y)
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

    local y = 0
    if not isGravityEnabled then
        if love.keyboard.isDown("w") then
            y = y - 1
        end

        if love.keyboard.isDown("s") then
            y = y + 1
        end

        if love.keyboard.isDown("q") then
            x = x - 1
            y = y - 1
        end

        if love.keyboard.isDown("e") then
            x = x + 1
            y = y - 1
        end

        if love.keyboard.isDown("z") then
            x = x - 1
            y = y + 1
        end

        if love.keyboard.isDown("c") then
            x = x + 1
            y = y + 1
        end
    end

    local offsetY = 0
    if isGravityEnabled then
        if isInAir then
            player.jumpVelocityY = player.jumpVelocityY + GRAVITY_Y * deltaTime
            if player.isJumping then
                offsetY = player.jumpVelocityY * deltaTime
            else
                offsetY = GRAVITY_Y * deltaTime
            end
        else
            if player.isJumping then
                player.isJumping = false
            end

            offsetY = 0
        end
    end

    local n = slick.geometry.point.new(x, y)
    if groundNormal:lengthSquared() > 0 then
        local d = n:dot(groundNormal)
        groundNormal:multiplyScalar(d, n)
    end

    n:normalize(n)
    n:multiplyScalar(PLAYER_SPEED * deltaTime, n)

    local goalX, goalY = player.x + n.x, player.y + n.y + offsetY

    if goalX ~= player.x or goalY ~= player.y then
        local actualX, actualY, hits = world:move(player, goalX, goalY, nil, query)
        player.x, player.y = actualX, actualY

        if isGravityEnabled then
            for _, hit in ipairs(hits) do
                if player.isJumping then
                    if hit.normal.y < 0 then
                        player.jumpVelocityY = 0
                    end
                end
            end
        end

        return true
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
            slick.newBoxShape(w / 2 + w / 5, h - 150, w / 6, 60)
        )
    )

    return level
end

local world, player
function love.load()
    world = slick.newWorld(love.graphics.getWidth(), love.graphics.getHeight(), {
        quadTreeMaxData = 4,
        quadTreeX = 0,
        quadTreeY = 0
    })

    makeLevel(world)
    
    player = makePlayer(world)
    query = slick.newWorldQuery(world)
end

function love.mousepressed(x, y, button)
    if button == 1 then
        player.x, player.y = x - 16, y - 16
        world:update(player, player.x, player.y)
    end
end

function love.keypressed(key, _, isRepeat)
    if key == "tab" and not isRepeat then
        isGravityEnabled = not isGravityEnabled
    end
end

local time = 0
function love.update(deltaTime)
    local b = love.timer.getTime()
    local m = movePlayer(player, world, deltaTime)
    local a = love.timer.getTime()
    
    if m then
        time = (a - b) * 1000
    end
end

function love.draw()
    love.graphics.printf(string.format("Logic: %2.2f ms", time), 0, 0, love.graphics.getWidth(), "center")

    slick.drawWorld(world)
end
