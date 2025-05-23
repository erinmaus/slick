local lineSegment = require "slick.collision.lineSegment"
local point = require "slick.geometry.point"
local ray = require "slick.geometry.ray"
local rectangle  = require "slick.geometry.rectangle"
local segment = require "slick.geometry.segment"
local util = require "slick.util"
local worldQuery = require "slick.worldQuery"

--- @param node slick.collision.quadTreeNode
local function _drawQuadTreeNode(node)
    love.graphics.rectangle("line", node.bounds:left(), node.bounds:top(), node.bounds:width(), node.bounds:height())

    love.graphics.print(node.level, node.bounds:right() - 16, node.bounds:bottom() - 16)
end

local function _defaultFilter()
    return true
end

--- @param world slick.world
local function _drawShapes(world)
    local items = world:getItems()
    for _, item in ipairs(items) do
        local entity = world:get(item)
        for _, shape in ipairs(entity.shapes.shapes) do
            if util.is(shape, lineSegment) then
                --- @cast shape slick.collision.lineSegment
                love.graphics.line(shape.segment.a.x, shape.segment.a.y, shape.segment.b.x, shape.segment.b.y)
            elseif shape.vertexCount == 4 then
                love.graphics.polygon("line", shape.vertices[1].x, shape.vertices[1].y, shape.vertices[2].x,
                    shape.vertices[2].y, shape.vertices[3].x, shape.vertices[3].y, shape.vertices[4].x,
                    shape.vertices[4].y)
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
end

--- @param world slick.world
local function _drawText(world)
    local items = world:getItems()
    for _, item in ipairs(items) do
        local entity = world:get(item)
        for _, shape in ipairs(entity.shapes.shapes) do
            love.graphics.print(string.format("%.2f, %.2f", shape.bounds.topLeft.x, shape.bounds.topLeft.y), shape.vertices[1].x, shape.vertices[1].y)
            love.graphics.print(string.format("%.2f x %.2f", shape.bounds:width(), shape.bounds:height()), shape.vertices[1].x, shape.vertices[1].y + 8)
        end
    end
end

--- @param world slick.world
local function _drawNormals(world)
    local items = world:getItems()
    for _, item in ipairs(items) do
        local entity = world:get(item)
        for _, shape in ipairs(entity.shapes.shapes) do
            local localSize = math.max(shape.bounds:width(), shape.bounds:height()) / 8

            for i = 1, shape.vertexCount do
                local j = i % shape.vertexCount + 1

                local a = shape.vertices[i]
                local b = shape.vertices[j]

                if i <= shape.normalCount then
                    local n = shape.normals[i]
                    love.graphics.line((a.x + b.x) / 2, (a.y + b.y) / 2, (a.x + b.x) / 2 + n.x * localSize, (a.y + b.y) / 2 + n.y * localSize)
                end
            end
        end
    end
end

--- @class slick.draw.options
--- @field text boolean?
--- @field quadTree boolean?
--- @field normals boolean?
local defaultOptions = {
    text = true,
    quadTree = true,
    normals = true
}

--- @param world slick.world
--- @param queries { filter: slick.worldShapeFilterQueryFunc, shape: slick.geometry.shape }[]?
--- @param options slick.draw.options?
local function draw(world, queries, options)
    options = options or defaultOptions
    local drawText = options.text == nil and defaultOptions.text or options.text
    local drawQuadTree = options.quadTree == nil and defaultOptions.quadTree or options.quadTree
    local drawNormals = options.normals == nil and defaultOptions.normals or options.normals

    local bounds = rectangle.new(world.quadTree:computeExactBounds())
    local size = math.min(bounds:width(), bounds:height()) / 16

    love.graphics.push("all")

    local cr, cg, cb, ca = love.graphics.getColor()

    _drawShapes(world)

    if drawNormals then
        love.graphics.setColor(0, 1, 0, ca)
        _drawNormals(world)
        love.graphics.setColor(cr, cg, cb, ca)
    end
    
    if drawText then
        _drawText(world)
    end

    if queries then
        local query = worldQuery.new(world)
        for _, q in ipairs(queries) do
            local shape = q.shape
            local filter = q.filter

            love.graphics.setColor(0, 0.5, 1, 0.5)
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

            query:performPrimitive(shape, filter or _defaultFilter)

            love.graphics.setColor(1, 0, 0, 1)
            for _, result in ipairs(query.results) do
                love.graphics.rectangle("fill", result.contactPoint.x - 2, result.contactPoint.y - 2, 4, 4)
                for _, contact in ipairs(result.contactPoints) do
                    love.graphics.rectangle("fill", contact.x - 2, contact.y - 2, 4, 4)
                end
            end
        end
    end

    love.graphics.setColor(0, 1, 1, 0.5)
    if drawQuadTree then
        world.quadTree.root:visit(_drawQuadTreeNode)
    end

    love.graphics.pop()
end

return draw
