local slick = require("slick")

local shapes = {
    {
        name = "custom",

        contours = {
            {
                337, 182,
                538, 282,
                589, 208,
                684, 470,
                453, 695,
                173, 518,
            },

            {
                365, 261,
                515, 332,
                407, 559,
                278, 452
            }
        }
    }
}

do
    -- See: https://github.com/erinmaus/slick/issues/69
    local numPoints = 2 ^ 6
    
    local step = (2 * math.pi) / numPoints
    local vertices = {}
    for angle = 0, 2 * math.pi, step do
        local x = 0 + math.cos(angle) * 10
        local y = 0 + math.sin(angle) * 10
    
        table.insert(vertices, x)
        table.insert(vertices, y)
    end

    table.insert(shapes, {
        name = "big circle",
        contours = { vertices }
    })
end

do
    local items = love.filesystem.getDirectoryItems("test/data")

    for _, item in ipairs(items) do
        local filename = string.format("test/data/%s", item)

        local result = {
            name = item,
            contours = {}
        }

        local contour = {}
        table.insert(result.contours, contour)

        local mode = "shape"
        for line in love.filesystem.lines(filename) do
            local x, y = line:match("([^%s]+)%s+([^%s]+)")
            x = x and tonumber(x)
            y = y and tonumber(y)

            if x and y then
                if mode ~= "steiner" then
                    table.insert(contour, x)
                    table.insert(contour, y)
                end
            else
                mode = line:lower()

                if mode == "hole" then
                    contour = {}
                    table.insert(result.contours, contour)
                end
            end
        end

        table.insert(shapes, result)
    end
end

local subjectMinX, subjectMinY, subjectMaxX, subjectMaxY
local index = 1
local clipIndex = 1
local clipOperation
local triangles
local polygons

local clipModes = {
    [slick.newUnionClipOperation] = "union",
    [slick.newIntersectionClipOperation] = "intersection",
    [slick.newDifferenceClipOperation] = "difference",
}

local function getBounds(contours)
    local minX = nil
    local minY = nil
    local maxX = nil
    local maxY = nil

    for i = 1, #contours do
        local contour = contours[i]
        for i = 1, (#contour / 2) do
            minX = math.min(contour[(i - 1) * 2 + 1], minX or math.huge)
            maxX = math.max(contour[(i - 1) * 2 + 1], maxX or -math.huge)
            minY = math.min(contour[(i - 1) * 2 + 2], minY or math.huge)
            maxY = math.max(contour[(i - 1) * 2 + 2], maxY or -math.huge)
        end
    end

    return minX, minY, maxX, maxY
end

local function getClipContour()
    local otherMinX, otherMinY, otherMaxX, otherMaxY = getBounds(shapes[clipIndex].contours)
    local minX, minY, maxX, maxY = getBounds(shapes[index].contours)

    local w1 = maxX - minX
    local h1 = maxY - minY
    local w2 = love.graphics.getWidth()
    local h2 = love.graphics.getHeight()

    local w3 = otherMaxX - otherMinX
    local h3 = otherMaxY - otherMinY

    local transform = love.math.newTransform()
    transform:translate(-minX, -minY)
    transform:translate(w1 / 2, h1 / 2)
    transform:translate((w2 - w1) / 2, (h2 - h1) / 2)
    transform:translate(-w1 / 2, -h1 / 2)

    local mouseX, mouseY = transform:inverseTransformPoint(love.mouse.getPosition())

    local result = {}
    for _, inputContour in ipairs(shapes[clipIndex].contours) do
        local outputContour = {}

        for i = 1, #inputContour, 2 do
            local x, y = inputContour[i], inputContour[i + 1]
            x = (x - otherMinX) + mouseX - w3 / 2
            y = (y - otherMinY) + mouseY - h3 / 2

            table.insert(outputContour, x)
            table.insert(outputContour, y)
        end

        table.insert(result, outputContour)
    end

    return result
end

local function build()
    subjectMinX, subjectMinY, subjectMaxX, subjectMaxY = getBounds(shapes[index].contours)

    if clipOperation then
        local otherContours = getClipContour()
        triangles = slick.clip(clipOperation(shapes[index].contours, otherContours))
        polygons = slick.clip(clipOperation(shapes[index].contours, otherContours), math.huge)
    else
        triangles = slick.triangulate(shapes[index].contours)
        polygons = slick.polygonize(shapes[index].contours)
    end
end

build()

local showPolygons = false

local demo = {}
function demo.keypressed(key, _, isRepeat)
    if isRepeat then
        return
    end

    if key == "t" then
        showPolygons = false
    end

    if key == "p" then
        showPolygons = true
    end
    
    local isDirty = false

    local operation
    if key == "i" then
        operation = slick.newIntersectionClipOperation
    elseif key == "u" then
        operation = slick.newUnionClipOperation
    elseif key == "d" then
        operation = slick.newDifferenceClipOperation
    end

    if clipOperation == operation then
        clipOperation = nil
    elseif operation then
        clipOperation = operation
        isDirty = true
    end

    if key == "left" then
        if love.keyboard.isDown("lshift", "rshift") then
            clipIndex = ((clipIndex - 2) % #shapes) + 1
        else
            index = ((index - 2) % #shapes) + 1
        end

        isDirty = true
    end
    
    if key == "right" then
        if love.keyboard.isDown("lshift", "rshift") then
            clipIndex = (clipIndex % #shapes) + 1
        else
            index = (index % #shapes) + 1
        end

        isDirty = true
    end
    
    if isDirty then
        build()
    end
end

function demo.mousemoved(x, y)
    if clipOperation ~= nil then
        build()
    end
end

function demo.update()
    -- Nothing.
end

local help = [[
bill c. triangulation demo

triangulation controls
- p: show polygonization
- t: show triangulation
- left, right: move to next/previous clipping shape

clipping controls
- mouse: move clipping shape
- shift + left, shift + right: move to next/previous clipping shape
- d: toggle 'difference' clipping mode
- u: toggle 'union' clipping mode
- i: toggle 'intersection' clipping mode
]]

function demo.help()
    love.graphics.print(help, 8, 8)
end

function demo.draw()
    love.graphics.push("all")
    love.graphics.print(string.format("shape %s (%d): %d polygons, %d triangles", shapes[index].name, index, #polygons, #triangles), 8, 8)
    if clipOperation then
        love.graphics.print(string.format("clip %s (%d): operation %s", shapes[clipIndex].name, index, clipModes[clipOperation] or "???"), 8, 24)
    else
        love.graphics.print("(no clip operation active)", 8, 24)
    end

    local w1 = subjectMaxX - subjectMinX
    local h1 = subjectMaxY - subjectMinY
    local w2 = love.graphics.getWidth()
    local h2 = love.graphics.getHeight()

    love.graphics.translate(-subjectMinX, -subjectMinY)
    love.graphics.translate(w1 / 2, h1 / 2)
    love.graphics.translate((w2 - w1) / 2, (h2 - h1) / 2)
    love.graphics.translate(-w1 / 2, -h1 / 2)
    
    love.graphics.setLineJoin("none")
    love.graphics.setLineWidth(1)

    if showPolygons then
        for index = 1, #polygons do
            local polygon = polygons[index]

            love.graphics.setColor(0.1, 0.1, 0.6, 1)
            love.graphics.polygon("fill", polygon)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.polygon("line", polygon)
        end
    else
        for index = 1, #triangles do
            local triangle = triangles[index]
            
            love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
            love.graphics.polygon("fill", triangle)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.polygon("line", triangle)
        end
    end

    love.graphics.pop()
end

return demo
