local slick = require("slick")
local common = require("demo.common")

local GRAVITY_Y = 1100
local JUMP_POWER = 300
local PLAYER_SPEED = 350

local demo = {
    world = slick.newWorld(2000, 1000, {
        quadTreeX = 0,
        quadTreeY = 0
    })
}

local function makePlayer()
    local player = {
        type = "player",

        x = 340,
        y = 500,

        velocityX = 0,
        velocityY = 0,
        groundDrag = 10,
        airDrag = 1,

        w = 16,
        h = 32
    }

    demo.world:add(player, player.x, player.y, slick.newShapeGroup(
        slick.newRectangleShape(0, player.w / 2, player.h - player.w, player.w),
        slick.newCircleShape(player.w / 2, player.w / 2, player.w / 2),
        slick.newCircleShape(player.w / 2, player.h - player.w / 2, player.w / 2)
    ))

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

    return x, y
end

local function dot(x1, y1, x2, y2)
    local l1 = math.sqrt(x1 ^ 2 + y1 ^ 2)
    if l1 > 0 then
        x1 = x1 / l1
        y1 = y1 / l1
    end

    local l2 = math.sqrt(x2 ^ 2 + y2 ^ 2)
    if l2 > 0 then
        x2 = x2 / l2
        y2 = y2 / l2
    end

    return (x1 * x2) + (y1 * y2)
end

local function getPlayerGroundContactInfo(player)
    if player.velocityY < 0 then
        return false
    end

    local collisions = demo.world:project(player, player.x, player.y, player.x, player.y + 1)
    if #collisions == 0 then
        return false
    end

    for _, collision in ipairs(collisions) do
        local direction = dot(collision.normal.x, collision.normal.y, 0, 1)
        if direction < 0 then
            local normalX = -collision.normal.y
            local normalY = collision.normal.x

            return true, normalX, normalY
        end
    end

    return false
end

local function playerFilter(player, other, shape, otherShape)
    if otherShape.tag == "bounce" then
        return "bounce"
    end

    return true
end

local function updatePlayer(player, deltaTime)
    local inputX, inputY = getPlayerInput()

    local isOnGround, groundNormalX, groundNormalY = getPlayerGroundContactInfo(player)
    local didJump = false
    if isOnGround then
        if inputY ~= 0 then
            player.velocityY = inputY * JUMP_POWER
            isOnGround = false
            didJump = true
        else
            player.velocityY = 0
        end
    else
        local gravity = GRAVITY_Y
        if player.velocityY < 0 then
            gravity = gravity * 0.5
        end

        player.velocityY = player.velocityY + gravity * deltaTime
    end

    local xOffset = inputX * PLAYER_SPEED * deltaTime + player.velocityX * deltaTime
    local yOffset = player.velocityY * deltaTime

    local goalX, goalY
    if isOnGround then
        goalX = player.x + xOffset * groundNormalX
        goalY = player.y + xOffset * groundNormalY
    else
        goalX = player.x + xOffset
        goalY = player.y + yOffset
    end

    local drag = isOnGround and player.groundDrag or player.airDrag
    local decay = 1 / (1 + (deltaTime * drag))
    player.velocityX = player.velocityX * decay
    player.velocityY = player.velocityY * decay

    local actualX, actualY, collisions = demo.world:check(player, goalX, goalY, playerFilter)

    local hitGround = false
    if not isOnGround and not didJump then
        for _, collision in ipairs(collisions) do
            if math.abs(dot(collision.normal.x, collision.normal.y, 0, 1)) > 0.5 then
                local direction = dot(collision.normal.x, collision.normal.y, xOffset, yOffset)

                if not hitGround and direction < 0 and player.velocityY > 0 then
                    hitGround = true

                    actualX = collision.touch.x
                    actualY = collision.touch.y
                end

                if direction < 0 and player.velocityY < 0 then
                    player.velocityY = 0
                end
            end

            if collision.response == "bounce" then
                player.velocityX = collision.extra.bounceNormal.x * JUMP_POWER
                player.velocityY = collision.extra.bounceNormal.y * JUMP_POWER * 2
            end
        end
    end

    demo.world:update(player, actualX, actualY)

    if inputX ~= 0 and not didJump and isOnGround then
        collisions = demo.world:project(player, actualX, actualY, actualX, actualY + GRAVITY_Y * deltaTime)
        if #collisions > 0 then
            for _, collision in ipairs(collisions) do
                if math.abs(collision.normal.y) > 0 then
                    actualY = collision.touch.y
                    break
                end
            end

            actualX, actualY = demo.world:move(player, actualX, actualY)
        end
    end

    player.x, player.y = actualX, actualY
end

local function makeLevel()
    local level = { type = "level", bounce = false }

    demo.world:add(level, 0, 0, slick.newShapeGroup(
        slick.newRectangleShape(0, 900, 2000, 100),
        slick.newRectangleShape(0, 0, 100, 900),
        slick.newRectangleShape(1900, 0, 100, 900),
        slick.newPolygonMeshShape({
            100, 600,
            200, 650,
            300, 600,
            400, 600,
            500, 650,
            600, 550,
            1200, 800,
            1200, 1000,
            100, 1000
        }),
        slick.newCircleShape(250, 550, 25, nil, slick.newTag("bounce")),
        slick.newCircleShape(1350, 750, 25, nil, slick.newTag("bounce")),
        slick.newCircleShape(1400, 600, 25, nil, slick.newTag("bounce")),
        slick.newCircleShape(1600, 400, 50, nil, slick.newTag("bounce")),
        slick.newRectangleShape(1200, 800, 100, 200),
        slick.newRectangleShape(1300, 850, 100, 150),
        slick.newRectangleShape(1700, 500, 100, 200)
    ))

    return level
end

demo.player = makePlayer()
demo.level = makeLevel()

demo.gears = {
    common.makeGear(demo.world, 500, 400, common.makeGearShape()),
    common.makeGear(demo.world, 750, 300, common.makeGearShape()),
    common.makeGear(demo.world, 1000, 200, common.makeGearShape()),
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
luigini player controls

- a, d: move left and right
- w: jump

- left, right: move left and right (alternative)
- up: jump (alternative)
]]

function demo.help()
    love.graphics.print(help, 8, 8)
end

return demo