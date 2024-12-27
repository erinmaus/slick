local circle = require "slick.collision.circle"
local lineSegment = require "slick.collision.lineSegment"
local point = require "slick.geometry.point"
local ray = require "slick.geometry.ray"
local rectangle  = require "slick.geometry.rectangle"
local segment = require "slick.geometry.segment"
local util = require "slick.util"
local worldQuery = require "slick.worldQuery"

--- @param node slick.collision.quadTreeNode
local function drawQuadTreeNode(node)
    love.graphics.rectangle("line", node.bounds:left(), node.bounds:top(), node.bounds:width(), node.bounds:height())

    love.graphics.print(node.level, node.bounds:right() - 16, node.bounds:bottom() - 16)
end

--- @param world slick.world
--- @param queries { filter: slick.worldShapeFilterQueryFunc, shape: slick.geometry.shape }[]?
local function draw(world, queries)
    local bounds = rectangle.new(world.quadTree:computeExactBounds())
    local size = math.min(bounds:width(), bounds:height()) / 16

    love.graphics.push("all")

    local items = world:getItems()
    for _, item in ipairs(items) do
        local entity = world:get(item)
        for _, shape in ipairs(entity.shapes.shapes) do
            if util.is(shape, circle) then
                --- @cast shape slick.collision.circle
                love.graphics.circle("line", shape.center.x, shape.center.y, shape.radius)
            elseif util.is(shape, lineSegment) then
                --- @cast shape slick.collision.lineSegment
                love.graphics.line(shape.segment.a.x, shape.segment.a.y, shape.segment.b.x, shape.segment.b.y)
            else
                for i = 1, shape.vertexCount do
                    local j = i % shape.vertexCount + 1

                    local a = shape.vertices[i]
                    local b = shape.vertices[j]

                    love.graphics.line(a.x, a.y, b.x, b.y)
                end
            end
        end
    end

    if queries then
        local r, g, b = love.graphics.getColor()

        local query = worldQuery.new(world)
        for _, q in ipairs(queries) do
            local shape = q.shape
            local filter = q.filter

            love.graphics.setColor(r, g, b, 0.5)
            if util.is(shape, point) then
                --- @cast shape slick.geometry.point
                love.graphics.circle("fill", shape.x, shape.y, 4)
            elseif util.is(shape, ray) then
                --- @cast shape slick.geometry.ray
                love.graphics.line(shape.origin.x, shape.origin.y, shape.origin.x + shape.direction.x * size, shape.origin.y + shape.direction.y * size)
                
                local left = point.new()
                shape.direction:left(left)
                
                local right = point.new() 
                shape.direction:right(right)

                love.graphics.line(
                    shape.origin.x + shape.direction.x * (size / 2) - left.x * (size / 2),
                    shape.origin.y + shape.direction.y * (size / 2) - left.y * (size / 2),
                    shape.origin.x + shape.direction.x * size,
                    shape.origin.y + shape.direction.y * size)
                love.graphics.line(
                    shape.origin.x + shape.direction.x * (size / 2) - right.x * (size / 2),
                    shape.origin.y + shape.direction.y * (size / 2) - right.y * (size / 2),
                    shape.origin.x + shape.direction.x * size,
                    shape.origin.y + shape.direction.y * size)
            elseif util.is(shape, rectangle) then
                --- @cast shape slick.geometry.rectangle
                love.graphics.rectangle("line", shape:left(), shape:top(), shape:width(), shape:height())
            elseif util.is(shape, segment) then
                --- @cast shape slick.geometry.segment
                love.graphics.line(shape.a.x, shape.a.y, shape.b.x, shape.b.y)
            end

            query:performPrimitive(shape, filter)

            love.graphics.setColor(1, 0, 0, 1)
            for _, result in ipairs(query.results) do
                love.graphics.rectangle("fill", result.contactPoint.x - 2, result.contactPoint.y - 2, 4, 4)
            end
        end
    end

    love.graphics.setColor(0, 1, 1, 0.5)
    world.quadTree.root:visit(drawQuadTreeNode)

    love.graphics.pop()
end

return draw
