local json = require("demo.json")
local slick = require("slick")

local shapes = json.decode(love.filesystem.read("demo/mush.json"))

--- @type slick.navigation.mesh
local mesh

local pathfinder = slick.navigation.path.new({
    neighbor = function(fromX, fromY, fromUserdata, toX, toY, toUserdata)
        return not ((fromUserdata and fromUserdata.door) or (toUserdata and toUserdata.door)) or love.keyboard.isDown("k")
    end
})

--- @type number[] | false
local path = false

--- @type number
local generationTimeMS

--- @type number
local pathFindTimeMS

local BACKGROUND = slick.newEnum("background")
local WALL = slick.newEnum("wall")
local DOOR = slick.newEnum("door")

local function generate()
    local meshBuilder = slick.navigation.meshBuilder.new()

    local function _addLayer(t, layer, combineMode, userdata)
        meshBuilder:addLayer(t, combineMode)

        for _, shape in ipairs(layer) do
            if #shape == 4 then
                meshBuilder:addShape(t, slick.newLineSegmentShape(shape[1], shape[2], shape[3], shape[4]), userdata)
            elseif #shape == 8 then
                meshBuilder:addShape(t, slick.newPolylineShape({
                    { shape[1], shape[2], shape[3], shape[4] },
                    { shape[5], shape[6], shape[7], shape[8] }
                }), userdata)
            else
                meshBuilder:addShape(t, slick.newPolygonMeshShape(shape), userdata)
            end
        end
    end

    local before = love.timer.getTime()
    _addLayer(BACKGROUND, shapes[BACKGROUND.value], "union")
    _addLayer(DOOR, shapes[DOOR.value], "union", { door = true })
    _addLayer(WALL, shapes[WALL.value], "difference")

    mesh = meshBuilder:build({
        dissolve = function(dissolve)
            dissolve.resultUserdata = dissolve.userdata or dissolve.otherUserdata
        end,

        intersect = function(intersect)
            intersect.resultUserdata = intersect.a1Userdata or intersect.a2Userdata or intersect.b1Userdata or intersect.b2Userdata 
        end,

        merge = function(merge)
            merge.resultUserdata = merge.sourceUserdata
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

    local before = love.timer.getTime()
    path = pathfinder:nearest(mesh, startX, startY, goalX, goalY) or false
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

function demo.draw()
    love.graphics.push("all")

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    love.graphics.translate(
        (width - mesh.bounds:width()) / 2,
        (height - mesh.bounds:height()) / 2)
        
    for _, triangle in ipairs(mesh.triangles) do
        local i, j, k = unpack(triangle)
        
        love.graphics.setColor(0.2, 0.8, 0.3, 0.5)
        love.graphics.polygon(
            "fill",
            mesh.vertices[i].point.x, mesh.vertices[i].point.y,
            mesh.vertices[j].point.x, mesh.vertices[j].point.y,
            mesh.vertices[k].point.x, mesh.vertices[k].point.y)
            
        for i = 1, #triangle do
            local j = (i % #triangle) + 1
            
            local a = mesh:getVertex(triangle[i])
            local b = mesh:getVertex(triangle[j])

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
            --local ax, ay, bx, by = unpack(path, i, i + 3)
            --love.graphics.line(ax, ay, bx, by)

            local j = i + 1
            
            local a = path[i]
            local b = path[j]
            
            love.graphics.line(a.point.x, a.point.y, b.point.x, b.point.y)
        end
    end

    love.graphics.pop()
end

return demo
