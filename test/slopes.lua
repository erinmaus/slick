local slick = require("slick")
local test = require("test.common.test")

test("should slide up hill composed of multiple triangles", function(t)
    local world = slick.newWorld(800, 600)

    local player = { x = 256, y = 256, width = 32, height = 32 }
    world:add(player, player.x, player.y, slick.newRectangleShape(0, 0, player.width, player.height))

    local SNAP = 32
    local function snap(n) return math.floor(n / SNAP) * SNAP end

    local function spawn_box(x, y)
        x, y = snap(x), snap(y)
        local box = { x = x, y = y, type = "wall", is_wall = true }
        local shape = slick.newRectangleShape(0, 0, SNAP, SNAP)
        world:add(box, x, y, shape)
    end

    local slope_rotation = 90
    local function spawn_slope(x, y)
        x, y = snap(x), snap(y)
        local vertices = { 0, 0, 32, 0, 32, 32 }
        local cx, cy = 16, 16
        local rad = math.rad(slope_rotation)
        local rotated = {}
        for i = 1, #vertices, 2 do
            local vx, vy = vertices[i], vertices[i + 1]
            local rx = (vx - cx) * math.cos(rad) - (vy - cy) * math.sin(rad) + cx + x
            local ry = (vx - cx) * math.sin(rad) + (vy - cy) * math.cos(rad) + cy + y
            table.insert(rotated, rx)
            table.insert(rotated, ry)
        end
        local shape = slick.newPolygonMeshShape(rotated)
        local slope = { x = x, y = y, type = "wall", is_wall = true, shape = shape, rotation = slope_rotation }
        world:add(slope, 0, 0, shape) -- vertices already include position
    end

    local CENTER_X, CENTER_Y = 256, 256
    spawn_box(CENTER_X, CENTER_Y + 32)
    spawn_slope(CENTER_X + 32, CENTER_Y)
    spawn_slope(CENTER_X + 64, CENTER_Y - 32)

    local collisions = t:moveUntilCollision(function(delta)
        local c
        player.x, player.y, c = world:move(player, player.x + 200 * delta, player.y)
        return c
    end)
    
    assert(#collisions == 1, "expected one collision")
    
    t:moveUntilNoCollision(function(delta)
        local c
        player.x, player.y, c = world:move(player, player.x + 200 * delta, player.y)
        return c
    end)

    assert(slick.util.math.greater(player.x, 320), slick.util.math.less(player.y, 192), "expected player to stop colliding and go past slopes")
end)