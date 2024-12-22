local slick = require("slick")

local shapes = {}
do
    local items = love.filesystem.getDirectoryItems("test/data")

    for _, item in ipairs(items) do
        local filename = string.format("test/data/%s", item)

        local result = {
            name = item,
            points = {},
            edges = {}
        }

        local startIndex = 1
        local lastIndex

        local mode = "shape"
        for line in love.filesystem.lines(filename) do
            local x, y = line:match("([^%s]+)%s+([^%s]+)")
            x = x and tonumber(x)
            y = y and tonumber(y)

            if x and y then
                table.insert(result.points, x)
                table.insert(result.points, y)

                if lastIndex and mode ~= "steiner" then
                    table.insert(result.edges, lastIndex)
                    table.insert(result.edges, (#result.points / 2))
                end

                lastIndex = #result.points / 2
            else
                if mode == "shape" or mode == "hole" then
                    table.insert(result.edges, lastIndex)
                    table.insert(result.edges, startIndex)
                end

                mode = line:lower()

                startIndex = #result.points / 2 + 1
                lastIndex = nil
            end
        end

        if mode == "shape" or mode == "hole" then
            table.insert(result.edges, lastIndex)
            table.insert(result.edges, startIndex)
        end

        table.insert(shapes, result)
    end
end

local minX, minY, maxX, maxY
local options = {
    refine = true,
    interior = true,
    exterior = false,
    polygonization = true
}

local index = 15
local shape, edges
local triangles, trianglesCount
local polygons, polygonCount
local time, memory

local triangulator = slick.geometry.triangulation.delaunay.new()
local function build()
    collectgarbage("stop")
    local memoryBefore = collectgarbage("count")
    local timeBefore = love.timer.getTime()
    shape, edges = triangulator:clean(shapes[index].points, shapes[index].edges, nil, nil, shape, edges)
    triangles, trianglesCount, polygons, polygonCount = triangulator:triangulate(shape, edges, options, triangles, polygons)
    local timeAfter = love.timer.getTime()
    local memoryAfter = collectgarbage("count")
    collectgarbage("restart")

    time = (timeAfter - timeBefore) * 1000
    memory = memoryAfter - memoryBefore

    minX = nil
    minY = nil
    maxX = nil
    maxY = nil

    for i = 1, (#shape / 2) do
        minX = math.min(shape[(i - 1) * 2 + 1], minX or math.huge)
        maxX = math.max(shape[(i - 1) * 2 + 1], maxX or -math.huge)
        minY = math.min(shape[(i - 1) * 2 + 2], minY or math.huge)
        maxY = math.max(shape[(i - 1) * 2 + 2], maxY or -math.huge)
    end
end

build()

local showPolygons = false
local showTriangles = true

function love.keypressed(key)
    if key == "1" then
        options.refine = not options.refine
    end

    if key == "2" then
        options.interior = not options.interior
    end

    if key == "3" then
        options.exterior = not options.exterior
    end

    if key == "t" then
        showTriangles = not showTriangles
    end

    if key == "p" then
        showPolygons = not showPolygons
    end

    if key == "left" then
        index = ((index - 2) % #shapes) + 1
    end
    
    if key == "right" or key == "space" then
        index = (index % #shapes) + 1
    end

    
    build()
end

function love.draw()
    love.graphics.push("all")
    love.graphics.print(string.format("%f ms, %f kb", time, memory), 0, 0)
    love.graphics.print(string.format("%d polygons, %d triangles", polygonCount or 0, trianglesCount), 0, 16)
    love.graphics.print(table.concat({
        string.format("delaunay? %s", options.refine and "yes" or "no"),
        string.format("interior? %s", options.interior and "yes" or "no"),
        string.format("exterior? %s", options.exterior and "yes" or "no"),
    }, "\n"), 0, 32)

    local w1 = maxX - minX
    local h1 = maxY - minY
    local w2 = love.graphics.getWidth()
    local h2 = love.graphics.getHeight()
    
    --love.graphics.translate(w2 / 2, h2 / 2)
    love.graphics.translate(-minX, -minY)
    love.graphics.translate(w1 / 2, h1 / 2)
    love.graphics.translate((w2 - w1) / 2, (h2 - h1) / 2)
    love.graphics.translate(-w1 / 2, -h1 / 2)
    
    love.graphics.setLineJoin("none")
    love.graphics.setLineWidth(1)

    if showPolygons then
        for index = 1, polygonCount or 0 do
            local polygon = polygons[index]
            local vertices = {}

            for i = 1, #polygon do
                table.insert(vertices, shape[(polygon[i] - 1) * 2 + 1])
                table.insert(vertices, shape[(polygon[i] - 1) * 2 + 2])
            end

            love.graphics.setColor(0.1, 0.1, 0.6, 1)
            love.graphics.polygon("fill", vertices)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.polygon("line", vertices)
        end
    end

    if showTriangles then
        for index = 1, trianglesCount do
            local triangle = triangles[index]
            
            local point1 = triangle[1]
            point1 = (point1 - 1) * 2 + 1
            local point2 = triangle[2]
            point2 = (point2 - 1) * 2 + 1
            local point3 = triangle[3]
            point3 = (point3 - 1) * 2 + 1
            
            local x1, y1 = unpack(shape, point1, point1 + 1)
            local x2, y2 = unpack(shape, point2, point2 + 1)
            local x3, y3 = unpack(shape, point3, point3 + 1)
            
            love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
            love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.polygon("line", x1, y1, x2, y2, x3, y3)

            love.graphics.setColor(1, 0, 0, 1)
            local centerX = (x1 + x2 + x3) / 3
            local centerY = (y1 + y2 + y3) / 3
            love.graphics.print(index, centerX - love.graphics.getFont():getWidth(index) / 2, centerY - 8)
        end
    end

    if love.keyboard.isDown("e") then
        for i = 1, #edges, 2 do
            local edge1 = edges[i]
            edge1 = (edge1 - 1) * 2 + 1

            local edge2 = edges[i + 1]
            edge2 = (edge2 - 1) * 2 + 1

            local x1, y1 = unpack(shape, edge1, edge1 + 1)
            local x2, y2 = unpack(shape, edge2, edge2 + 1)

            love.graphics.setColor(0, 1, 0, 1)
            love.graphics.line(x1, y1, x2, y2)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(edges[i], x1, y1)
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, #shape, 2 do
        local x, y = unpack(shape, i, i + 1)

        if love.keyboard.isDown("space") then
            love.graphics.print(math.ceil(i / 2), x - love.graphics.getFont():getWidth(math.ceil(i / 2)) / 2, y - 16)
        end

        love.graphics.circle("fill", x, y, 2)
    end

    love.graphics.pop()
end

