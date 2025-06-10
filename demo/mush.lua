local json = require("demo.json")
local slick = require("slick")

local shapes = json.decode(love.filesystem.read("demo/mush.json"))

--- @type slick.navigation.mesh
local mesh

local pathfinder = slick.navigation.path.new()

--- @type slick.navigation.vertex[] | false
local path = false

--- @type number
local generationTimeMS

--- @type number
local pathFindTimeMS

local BACKGROUND = slick.newEnum("background")
local WALL = slick.newEnum("wall")

local function generate()
    local meshBuilder = slick.navigation.meshBuilder.new()

    local function _addLayer(t, layer)
        meshBuilder:addLayer(t)

        for _, shape in ipairs(layer) do
            local points = shape.points

            local edges = {}

            local n = #points / 2
            for i = 1, n do
                table.insert(edges, i)
                table.insert(edges, (i % n) + 1)
            end

            meshBuilder:addMesh(t, slick.navigation.mesh.new(points, {}, edges))
        end
    end

    local before = love.timer.getTime()
    _addLayer(BACKGROUND, shapes[BACKGROUND.value])
    _addLayer(WALL, shapes[WALL.value])

    mesh = meshBuilder:build({
        dissolve = function(dissolve)
            dissolve.resultUserdata = dissolve.userdata or dissolve.otherUserdata
        end,

        intersect = function(intersect)
            intersect.resultUserdata = intersect.a1Userdata or intersect.a2Userdata or intersect.b1Userdata or intersect.b2Userdata 
        end
    })

    local after = love.timer.getTime()
    generationTimeMS = (after - before) * 1000
end

generate()

local demo = {}

function demo.update(delta)
    -- Nothing.
end

local function getDemoTransform()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    local translation = love.math.newTransform(
        (width - mesh.bounds:width()) / 2,
        (height - mesh.bounds:height()) / 2)

    return translation
end

local startX, startY
local goalX, goalY
local function findPath()
    if not (startX and startY) or not (goalX and goalY) then
        path = false
        return
    end

    local hasGoal = mesh:getContainingTriangle(goalX, goalY)
    if not hasGoal then
        return
    end

    local before = love.timer.getTime()
    do
        local _, p = pathfinder:nearest(mesh, startX, startY, goalX, goalY)
        path = p or false
    end
    local after = love.timer.getTime()
    pathFindTimeMS = (after - before) * 1000
end

function demo.mousepressed(x, y)
    local translation = getDemoTransform()
    startX, startY = translation:inverseTransformPoint(x, y)
end

function demo.mousemoved(x, y)
    if not (startX and startY) then
        return
    end

    local translation = getDemoTransform()
    goalX, goalY = translation:inverseTransformPoint(x, y)

    findPath()
end

function demo.keypressed(key, _, isRepeat)
    if key == "k" and not isRepeat then
        findPath()
    end
end

function demo.keyreleased(key, _, isRepeat)
    if key == "k" and not isRepeat then
        findPath()
    end
end

local help = [[
mush navigation mesh demo

controls
- mouse left click: place "start" point
- move mouse: move "goal" point
]]

function demo.help()
    love.graphics.print(help, 8, 8)
end

function demo.draw()
    love.graphics.push("all")
    love.graphics.print(string.format("generation time: %.2f ms", generationTimeMS or 0), 8, 8)
    love.graphics.print(string.format("pathfinding time: %.2f ms", pathFindTimeMS or 0), 8, 24)

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    love.graphics.translate(
        (width - mesh.bounds:width()) / 2,
        (height - mesh.bounds:height()) / 2)
        
    for _, triangle in ipairs(mesh.triangles) do
        local i, j, k = unpack(triangle.triangle)
        
        love.graphics.setColor(0.2, 0.8, 0.3, 0.5)
        love.graphics.polygon(
            "fill",
            i.point.x, i.point.y,
            j.point.x, j.point.y,
            k.point.x, k.point.y)
            
        for i = 1, #triangle.triangle do
            local j = (i % #triangle.triangle) + 1
            
            local a = triangle.triangle[i]
            local b = triangle.triangle[j]

            if a.userdata and a.userdata.door and b.userdata and b.userdata.door then
                love.graphics.setLineWidth(4)
                love.graphics.setColor(1, 0, 0, 0.5)
            else
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1, 1, 1, 0.5)
            end

            love.graphics.line(a.point.x, a.point.y, b.point.x, b.point.y)
        end
    end

    local mouseX, mouseY = love.graphics.inverseTransformPoint(love.mouse.getPosition())
    
    -- For some reason LLS forgets mesh is a slick.navigation.mesh here
    --- @cast mesh slick.navigation.mesh
    
    local triangle = mesh:getContainingTriangle(mouseX, mouseY)
    if triangle then
        love.graphics.rectangle("fill", mouseX - 4, mouseY - 4, 8, 8)

        for i = 1, #triangle do
            local j = (i % #triangle) + 1

            local a = mesh:getVertex(triangle[i])
            local b = mesh:getVertex(triangle[j])

            love.graphics.line(a.point.x, a.point.y, b.point.x, b.point.y)
        end
    end
    
    if path then
        love.graphics.setLineWidth(4)
        love.graphics.setColor(1, 1, 0, 1)

        for i = 1, #path - 1 do
            local j = i + 1

            local a = path[i]
            local b = path[j]

            love.graphics.line(a.point.x, a.point.y, b.point.x, b.point.y)
        end
    end

    love.graphics.pop()
end

return demo
