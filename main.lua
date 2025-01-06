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

        x = love.graphics.getWidth() / 2,
        y = love.graphics.getHeight() / 8,
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

    world:add(player, x, y, slick.newShapeGroup(
        --slick.newBoxShape(0, 0, player.w, player.h),
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
local up = slick.geometry.point.new(0, 1)
local left = slick.geometry.point.new(-1, 0)
local right = slick.geometry.point.new(1, 0)
local transform = slick.newTransform()
local function movePlayer(player, world, deltaTime)
    --- @cast world slick.world

    local isInAir = true
    local canMoveLeft = true
    local canMoveRight = true
    if isGravityEnabled then
        world:queryCircle(player.x + player.w / 2, player.y + player.h + 1, player.w / 2 + 1, notPlayerFilter, query)

        for _, result in ipairs(query.results) do
            local upD = result.normal:dot(up)
            if upD < -0.5 then
                isInAir = false
            end
            
            local leftD = result.normal:dot(left)
            if leftD > 0.8 then
                canMoveRight = false
            end
            
            local rightD = result.normal:dot(right)
            if rightD > 0.8 then
                canMoveLeft = false
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
    if love.keyboard.isDown("a") and canMoveLeft then
        x = x - 1
    end
    
    if love.keyboard.isDown("d") and canMoveRight then
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
                    local dot = hit.normal:dot(up)
                    if dot >= 0 then
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
            slick.newBoxShape(w / 2 + w / 5, h - 150, w / 5, 60),
            slick.newCircleShape(w / 2 - 64, h - 256, 128)
        )
    )

    world:add({ type = level }, slick.newTransform(w / 3, h / 3, -math.pi / 4), slick.newBoxShape(-w / 8, -30, w / 4, 60))

    return level
end

local world, player
function love.load()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    world = slick.newWorld(w * 2, h * 2, {
        quadTreeMaxData = 8,
        quadTreeX = -w,
        quadTreeY = -h
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

local function touchFilter()
    return "touch"
end

local points = {}
function love.mousepressed(x, y, button)
    local t = getCameraTransform()
    x, y = t:inverseTransformPoint(x, y)
    if button == 1 then
        if love.keyboard.isDown("lshift", "rshift") then
            player.x, player.y = world:move(player, x, y, touchFilter, query)
        else
            player.x, player.y = x - 16, y - 16
            player.x, player.y = world:push(player, player.x, player.y)
        end
    elseif button == 2 then
        table.insert(points, x)
        table.insert(points, y)
    end
end

local contours = {}
function love.keypressed(key, _, isRepeat)
    if key == "tab" and not isRepeat then
        isGravityEnabled = not isGravityEnabled
    elseif key == "`" and not isRepeat then
        isZoomEnabled = not isZoomEnabled
    elseif key == "escape" and not isRepeat then
        isQueryEnabled = not isQueryEnabled
    elseif key == "return" and not isRepeat then
        if #points >= 6  then
            table.insert(contours, points)
            points = {}
        end

        if not love.keyboard.isDown("lshift", "rshift") then
            if #contours > 0 then
                world:add({ type = "level" }, 0, 0, slick.newPolygonMeshShape(unpack(contours)))
                
                contours = {}
            end
        end
    end
end

local time, memory = 0, 0
function love.update(deltaTime)
    collectgarbage("stop")
    local memoryBefore = collectgarbage("count")
    local timeBefore = love.timer.getTime()
    local didMove = movePlayer(player, world, 1 / 120)
    local timeAfter = love.timer.getTime()
    local memoryAfter = collectgarbage("count")
    collectgarbage("restart")
    
    if didMove then
        time = (timeAfter - timeBefore) * 1000
        memory = (memoryAfter - memoryBefore)
        love.timer.sleep(0.2)
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

    if #contours > 0 then
        love.graphics.setColor(1, 1, 0, 0.5)
        for _, contour in ipairs(contours) do
            love.graphics.line(unpack(contour))
            love.graphics.line(contour[1], contour[2], contour[#contour - 1], contour[#contour - 2])
        end
    end
    
    if #points >= 2 then
        local alpha = math.abs(math.sin(love.timer.getTime())) * 0.5 + 0.5
        love.graphics.setColor(0, 1, 0, alpha)
        if #points >= 4 then
            love.graphics.line(unpack(points))
        end

        local x, y = t:transformPoint(love.mouse.getPosition())
        love.graphics.line(points[#points - 1], points[#points], x, y)
    end

    love.graphics.pop()
end

function love.quit()
    love.filesystem.write("data.txt", string.format("%f %f", player.x, player.y))
end
