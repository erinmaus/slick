local lg = love.graphics
local slick = require "slick"
local world = slick.newWorld(200, 200)

local idx = 0
local function newBlock(x, y)
    idx = idx + 1

    local b = {}
    b.x = x
    b.y = y
    b.tag = idx
    local shape = slick.newRectangleShape(0, 0, 1, 1, slick.newTag(idx))
    world:add(b, x, y, shape)
    return b
end

local blocks = {}
for i = -3, 2 do
    table.insert(blocks, newBlock(0, i))
    table.insert(blocks, newBlock(1, i))
end

local player = {}
player.x = -0.6
player.y = 0
player.w = 0.6
player.h = 0.6

player.shape = slick.newRectangleShape(0, 0, player.w, player.h, slick.newTag("fo"))
world:add(player, player.x, player.y, player.shape)

function love.update(dt)
    local speed = 10
    if love.keyboard.isDown("w") then
        player.y = player.y - speed * dt
    end
    if love.keyboard.isDown("s") then
        player.y = player.y + speed * dt
    end

    if love.keyboard.isDown("a") then
        player.x = player.x - speed * dt
    end
    if love.keyboard.isDown("d") then
        player.x = player.x + speed * dt
    end

    local collisions
    player.x, player.y, collisions = world:move(player, player.x, player.y)

    for _, entry in pairs(collisions) do
        print(entry.normal.x, " ", entry.normal.y, "tag", entry.otherShape.tag)
    end
end

function love.draw()
    -- The base transforms needed to make the coordinates on screen go from -1, 1 for the height
    lg.translate(lg.getWidth() * 0.5, lg.getHeight() * 0.5)
    local scale = lg.getHeight() * 0.5 * 0.25
    lg.scale(scale)
    lg.setLineWidth(1 / scale)

    for i, block in ipairs(blocks) do
        local x, y = block.x, block.y
        lg.rectangle("line", x, y, 1, 1)
        love.graphics.print(block.tag, x + 0.25, y + 0.25, 0, 1 / lg.getWidth() * 8, 1 / lg.getHeight() * 8)
    end

    lg.rectangle("fill", player.x, player.y, player.w, player.h)
end
