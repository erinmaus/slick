if love.system.getOS() == "OS X" and jit and jit.arch == "arm64" then
    jit.off()
end

local slick = require("slick")

local GRAVITY_Y = 1200
local PLAYER_SPEED = 500
local PLAYER_JUMP_VELOCITY = 800
local PLAYER_ROTATION_SPEED = math.pi / 2
local isGravityEnabled = false
local isZoomEnabled = false
local isQueryEnabled = false
local query

local function makePlayer(world)
    local player = {
        type = "player",

        --x = love.graphics.getWidth() / 2,
        x = 536.6 + 16,
        --y = love.graphics.getHeight() / 8,
        y = 430,
        w = 32,
        h = 32,
        nx = 0,
        ny = 0,
        rotation = 0,
        
        jumpVelocityY = 0,
        isJumping = false
    }

    local x, y = (love.filesystem.read("data.txt") or ""):match("([^%s]+)%s+([^%s]+)")
    x = tonumber(x or player.x)
    y = tonumber(y or player.y)

    --world:add(player, x, y, slick.newBoxShape(0, 0, player.w, player.h))
    --world:add(player, x, y, slick.newCircleShape(0, 0, player.w / 2))
    world:add(player, x, y, slick.newShapeGroup(
        slick.newBoxShape(0, 0, player.w, player.h),
        slick.newCircleShape(player.w / 2, 0, player.w / 2),
        slick.newCircleShape(player.w / 2, player.h, player.w / 2)
    ))

    player.x = x
    player.y = y

    return player
end

local function notPlayerFilter(item)
    return item.type ~= "player"
end

local normal = slick.geometry.point.new()
local transform = slick.newTransform()
local function movePlayer(player, world, deltaTime)
    --- @cast world slick.world
    
    local isInAir = true
    if isGravityEnabled then
        local p = world:get(player)
        world:queryRectangle(p.bounds:left(), p.bounds:bottom(), p.bounds:width(), 2, notPlayerFilter, query)

        for _, result in ipairs(query.results) do
            if result.normal.y > 0 then
                isInAir = false
            end
        end
    end

    if not isInAir and love.keyboard.isDown("w") then
        player.isJumping = true
        player.jumpVelocityY = -PLAYER_JUMP_VELOCITY
        isInAir = true
    end

    local rx = 0
    if love.keyboard.isDown("left") then
        rx = rx - 1
    end
    if love.keyboard.isDown("right") then
        rx = rx + 1
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

    normal:init(x, y)
    normal:normalize(normal)
    normal:multiplyScalar(PLAYER_SPEED * deltaTime, normal)

    local goalX, goalY = player.x + normal.x, player.y + normal.y + offsetY

    if goalX ~= player.x or goalY ~= player.y or rx ~= 0 then
        player.rotation = player.rotation + rx * deltaTime * PLAYER_ROTATION_SPEED

        transform:init(player.x, player.y, player.rotation)
        world:update(player, transform)

        local actualX, actualY, hits = world:move(player, goalX, goalY, nil, query)
        player.x, player.y = actualX, actualY
        player.nx = normal.x
        player.ny = normal.y + offsetY

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
            slick.newPolygonMeshShape({ w - w / 4, h, w - 8, h / 2, w - 8, h }, { w - w / 4, h, w - 8, h / 2, w - 8, h }),
            slick.newBoxShape(w / 2 + w / 5, h - 150, w / 6, 60),
            slick.newCircleShape(w / 2 - 64, h - 256, 128)
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

local function getCameraTransform()
    local t = love.math.newTransform()
    if isZoomEnabled then
        local mx, my = love.mouse.getPosition()
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        t:translate(-mx - w / 2, -my - h / 2)
        t:translate(-w / 2, -h / 2)
        t:scale(2)
        t:translate(w / 2, h / 2)
    end

    return t
end

function love.mousepressed(x, y, button)
    local t = getCameraTransform()
    x, y = t:inverseTransformPoint(x, y)
    if button == 1 then
        player.x, player.y = x - 16, y - 16
        world:update(player, player.x, player.y)
    elseif button == 2 then
        player.x, player.y = world:move(player, x, y, function() return "touch" end, query)
    end
end

function love.keypressed(key, _, isRepeat)
    if key == "tab" and not isRepeat then
        isGravityEnabled = not isGravityEnabled
    elseif key == "`" and not isRepeat then
        isZoomEnabled = not isZoomEnabled
    elseif key == "escape" and not isRepeat then
        isQueryEnabled = not isQueryEnabled
    end
end

local time, memory = 0, 0
function love.update(deltaTime)
    collectgarbage("stop")
    local memoryBefore = collectgarbage("count")
    local timeBefore = love.timer.getTime()
    local didMove = movePlayer(player, world, deltaTime)
    local timeAfter = love.timer.getTime()
    local memoryAfter = collectgarbage("count")
    collectgarbage("restart")
    
    if didMove then
        time = (timeAfter - timeBefore) * 1000
        memory = (memoryAfter - memoryBefore)
    end
end

local smallFont = love.graphics.getFont()
local bigFont = love.graphics.newFont(32)

function love.draw()
    love.graphics.push("all")
    love.graphics.setFont(smallFont)
    love.graphics.printf(string.format("Logic: %2.2f ms (%.2f kb)", time, memory), 0, 0, love.graphics.getWidth(), "center")
    
    love.graphics.setFont(bigFont)
    if isGravityEnabled then
        love.graphics.printf("2D Mario Platformer Mode", 0, 32, love.graphics.getWidth(), "center")
    else
        love.graphics.printf("2D Top-Down Zelda Mode", 0, 32, love.graphics.getWidth(), "center")
    end
    
    love.graphics.setFont(smallFont)

    local t = getCameraTransform()
    love.graphics.applyTransform(t)

    slick.drawWorld(world)

    if isQueryEnabled then
        local hits = world:project(player, player.x, player.y, player.x + player.nx, player.y + player.ny)

        for _, hit in ipairs(hits) do
            love.graphics.setColor(0, 1, 0, 1)
            love.graphics.line(hit.shape.center.x, hit.shape.center.y, hit.shape.center.x + hit.normal.x * 100, hit.shape.center.y + hit.normal.y * 100)

            local perpendicular = slick.geometry.point.new()
            hit.normal:left(perpendicular)
            
            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.line(hit.shape.center.x - perpendicular.x * 50, hit.shape.center.y - perpendicular.y * 50, hit.shape.center.x + perpendicular.x * 50, hit.shape.center.y + perpendicular.y * 50)

            for _, point in ipairs(hit.contactPoints) do
                love.graphics.setColor(1, 0, 0, 0.5)
                love.graphics.rectangle("fill", point.x - 2, point.y - 2, 4, 4)
            end

            love.graphics.setColor(0, 1, 0, 0.5)
            love.graphics.rectangle("fill", hit.touch.x - 2, hit.touch.y - 2, 4, 4)
        end
    end

    love.graphics.pop()
end

function love.quit()
    love.filesystem.write("data.txt", string.format("%f %f", player.x, player.y))
end
