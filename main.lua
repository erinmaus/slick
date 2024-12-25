local slick = require("slick")

local shapes = {
    {
        name = "custom",

        points = {
            337, 182,
            538, 282,
            589, 208,
            684, 470,
            453, 695,
            173, 518,

            -- Hole
            365, 261,
            515, 332,
            407, 559,
            278, 452
        },

        edges = {
            1, 2,
            2, 3,
            3, 4,
            4, 5,
            5, 6,
            6, 1,

            7, 8,
            8, 9,
            9, 10,
            10, 7
        }
    }
}

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

local index = 1
local shape, edges
local triangles, trianglesCount
local polygons, polygonCount
local time, memory
local deletedPoints = {}

--- @type slick.collision.quadTree
local quadTree

--- @type slick.collision.polygon
local selfPolygon = slick.collision.polygon.new(nil, -50, -50, 100, -50, 100, 100, -50, 100)
local otherPolygons = {}

local query = slick.collision.shapeCollisionResolutionQuery.new()

local collision = false
local offset = slick.geometry.point.new()

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

    if polygons then
        slick.util.table.clear(otherPolygons)

        for i = 1, polygonCount do
            local polygonIndices = polygons[i]
            local polygonVertices = {}

            for i = 1, #polygonIndices do
                local x, y = unpack(shape, (polygonIndices[i] - 1) * 2 + 1, (polygonIndices[i] - 1) * 2 + 2)
                table.insert(polygonVertices, x)
                table.insert(polygonVertices, y)
            end

            table.insert(otherPolygons, slick.collision.polygon.new(unpack(polygonVertices)))
        end
    end

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

    quadTree = slick.collision.quadTree.new({ x = minX, y = minY, width = math.max(maxX - minX, 1), height = math.max(maxY - minY, 1) })
    slick.util.table.clear(deletedPoints)
    
    for i = 1, #shape / 2 do
        local index1 = (i - 1) * 2 + 1
        local index2 = index1 + 1
        
        local x = shape[index1]
        local y = shape[index2]
        
        quadTree:insert(i, x - 1, y - 1, x + 1, y + 1)
    end
end

build()

local showPolygons = true
local showTriangles = false
local showQuadTree = false

function love.keypressed(key)
    local rebuild = false

    if key == "1" then
        options.refine = not options.refine
        rebuild = true
    end

    if key == "2" then
        options.interior = not options.interior
        rebuild = true
    end

    if key == "3" then
        options.exterior = not options.exterior
        rebuild = true
    end

    if key == "t" then
        showTriangles = not showTriangles
    end

    if key == "p" then
        showPolygons = not showPolygons
    end

    if key == "q" then
        showQuadTree = not showQuadTree
    end

    if key == "left" then
        index = ((index - 2) % #shapes) + 1
        rebuild = true
    end
    
    if key == "right" or key == "space" then
        index = (index % #shapes) + 1
        rebuild = true
    end

    if rebuild then
        build()
    end
end

function love.mousemoved(x, y)
    local w1 = maxX - minX
    local h1 = maxY - minY
    local w2 = love.graphics.getWidth()
    local h2 = love.graphics.getHeight()

    local ox = minX - (w2 - w1) / 2
    local oy = minY - (h2 - h1) / 2
    local tx = x + ox
    local ty = y + oy

    local transform = slick.geometry.transform.new(tx, ty)
    selfPolygon:transform(transform)

    collision = false

    local largestDistance = -math.huge
    offset:init(0, 0)
    for i = 1, #otherPolygons do
        query:perform(selfPolygon, otherPolygons[i], slick.geometry.point.new(), slick.geometry.point.new())

        if query.collision then
            collision = true

            if query.depth > largestDistance then
                collision = true
                largestDistance = query.depth
                query.normal:multiplyScalar(query.depth, offset)
                offset.x = offset.x
                offset.y = offset.y
            end
        end
    end

    if love.mouse.isDown(1) then
        local query = slick.collision.quadTreeQuery.new(quadTree)
        local r = slick.geometry.rectangle.new(tx - 8, ty - 8, tx + 8, ty + 8)
        if query:perform(r) then
            for _, hit in ipairs(query.results) do
                quadTree:remove(hit)
                deletedPoints[hit] = true
            end
        end
    end
end

function love.draw()
    love.graphics.print(string.format("%d (%s): %f ms, %f kb", index, shapes[index].name, time, memory), 0, 0)
    love.graphics.print(string.format("%d polygons, %d triangles, %d points", polygonCount or 0, trianglesCount, math.floor(#shape / 2)), 0, 16)
    love.graphics.print(table.concat({
        string.format("1) delaunay? %s", options.refine and "yes" or "no"),
        string.format("2) interior? %s", options.interior and "yes" or "no"),
        string.format("3) exterior? %s", options.exterior and "yes" or "no"),
    }, "\n"), 0, 32)
    
    local w1 = maxX - minX
    local h1 = maxY - minY
    local w2 = love.graphics.getWidth()
    local h2 = love.graphics.getHeight()
    
    --love.graphics.translate(w2 / 2, h2 / 2)
    love.graphics.push("all")
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

            if not (deletedPoints[triangle[1]] or deletedPoints[triangle[2]] or deletedPoints[triangle[3]]) then
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
    end

    if showQuadTree then
        love.graphics.setColor(0, 1, 1, 0.5)

        quadTree.root:visit(function(node)
            love.graphics.rectangle("line", node:left(), node:top(), node:right() - node:left(), node:bottom() - node:top())
        end)
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
        if not deletedPoints[math.floor(i / 2) + 1] then
            local x, y = unpack(shape, i, i + 1)

            if love.keyboard.isDown("space") then
                love.graphics.print(math.ceil(i / 2), x - love.graphics.getFont():getWidth(math.ceil(i / 2)) / 2, y - 16)
            end

            love.graphics.circle("fill", x, y, 2)
        end
    end
    
    do
        local vertices = {}
        for i = 1, selfPolygon.vertexCount do
            table.insert(vertices, selfPolygon.vertices[i].x)
            table.insert(vertices, selfPolygon.vertices[i].y)
        end
        
        love.graphics.setColor(1, 0.5, 0.0, 0.5)
        love.graphics.polygon("fill", vertices)
        
        if collision then
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.push("all")
            love.graphics.translate(offset.x, offset.y)
            love.graphics.polygon("line", vertices)
            love.graphics.pop()
        end
    end
    love.graphics.pop()
end

