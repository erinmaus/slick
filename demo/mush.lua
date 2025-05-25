local slick = require("slick")

--- @type slick.navigation.mesh
local mesh
do
    local BACKGROUND = slick.newEnum("BACKGROUND")
    local WALL = slick.newEnum("WALL")

    local meshBuilder = slick.navigation.meshBuilder.new()

    meshBuilder:addLayer(BACKGROUND)
    meshBuilder:addLayer(WALL, "difference")

    meshBuilder:addShape(BACKGROUND, slick.newRectangleShape(0, 0, 400, 300))
    meshBuilder:addShape(BACKGROUND, slick.newLineSegmentShape(0, 0, 400, 300))
    meshBuilder:addShape(WALL, slick.newCircleShape(100, 100, 40))
    meshBuilder:addShape(WALL, slick.newRectangleShape(100, 200, 75, 128))

    mesh = meshBuilder:build()
end

local demo = {}

function demo.update(delta)
    -- Nothing.
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
        
        love.graphics.setColor(0.2, 0.5, 0.2, 0.5)
        love.graphics.polygon(
            "fill",
            mesh.vertices[i].point.x, mesh.vertices[i].point.y,
            mesh.vertices[j].point.x, mesh.vertices[j].point.y,
            mesh.vertices[k].point.x, mesh.vertices[k].point.y)
    end

    local mouseX, mouseY = love.graphics.inverseTransformPoint(love.mouse.getPosition())
    
    -- For some reason LLS forgets mesh is a slick.navigation.mesh here
    --- @cast mesh slick.navigation.mesh
    
    local triangle = mesh:getContainingTriangle(mouseX, mouseY)
    if triangle then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("fill", mouseX - 4, mouseY - 4, 8, 8)

        for i = 1, #triangle do
            local j = (i % #triangle) + 1

            local a = mesh:getVertex(triangle[i])
            local b = mesh:getVertex(triangle[j])

            love.graphics.line(a.point.x, a.point.y, b.point.x, b.point.y)
        end
    end

    love.graphics.pop()
end

return demo
