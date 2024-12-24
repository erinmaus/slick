local point = require("slick.geometry.point")
local rectangle = require("slick.geometry.rectangle")
local util = require("slick.util")
local slicktable = require("slick.util.slicktable")

--- @class slick.collision.quadTreeQuery
--- @field tree slick.collision.quadTree
--- @field results any[]
--- @field bounds slick.geometry.rectangle
--- @field private data table<any, boolean>
local quadTreeQuery = {}
local metatable = { __index = quadTreeQuery }

--- @param tree slick.collision.quadTree
--- @return slick.collision.quadTreeQuery
function quadTreeQuery.new(tree)
    return setmetatable({
        tree = tree,
        results = {},
        bounds = rectangle.new(),
        data = {}
    }, metatable)
end

--- @private
function quadTreeQuery:_beginQuery()
    slicktable.clear(self.results)
    slicktable.clear(self.data)

    self.bounds.topLeft:init(math.huge, math.huge)
    self.bounds.bottomRight:init(-math.huge, -math.huge)
end

--- @private
--- @param r slick.geometry.rectangle
function quadTreeQuery:_expand(r)
    self.bounds.topLeft.x = math.min(self.bounds.topLeft.x, r.topLeft.x)
    self.bounds.topLeft.y = math.min(self.bounds.topLeft.y, r.topLeft.y)
    self.bounds.bottomRight.x = math.max(self.bounds.bottomRight.x, r.bottomRight.x)
    self.bounds.bottomRight.y = math.max(self.bounds.bottomRight.y, r.bottomRight.y)
end

--- @private
function quadTreeQuery:_endQuery()
    if #self.results == 0 then
        self.bounds:init(0, 0, 0, 0)
    end
end

--- @private
--- @param node slick.collision.quadTreeNode?
--- @param p slick.geometry.point
function quadTreeQuery:_performPointQuery(node, p)
    if not node then
        node = self.tree.root
        self:_beginQuery()
    end

    if p.x >= node:left() and p.y <= node:right() and p.y >= node:top() and p.y <= node:bottom() then
        if #node.children > 0 then
            for _, c in ipairs(node.children) do
                self:_performPointQuery(c, p)
            end
        else
            for _, d in ipairs(node.data) do
                --- @diagnostic disable-next-line: invisible
                local r = self.tree.data[d]
                if not self.data[d] and p.x >= r:left() and p.y <= node:right() and p.y >= node:top() and p.y <= node:bottom() then
                    table.insert(self.results)
                    self.data[d] = true
                    self:_expand(r)
                end
            end
        end
    end
end

--- @private
--- @param node slick.collision.quadTreeNode?
--- @param r slick.geometry.rectangle
function quadTreeQuery:_performRectangleQuery(node, r)
    if not node then
        node = self.tree.root
        self:_beginQuery()
    end

    if r:overlaps(node.bounds) then
        if #node.children > 0 then
            for _, c in ipairs(node.children) do
                self:_performRectangleQuery(c, r)
            end
        else
            for _, d in ipairs(node.data) do
                --- @diagnostic disable-next-line: invisible
                local otherRectangle = self.tree.data[d]

                if not self.data[d] and r:overlaps(otherRectangle) then
                    table.insert(self.results, d)
                    self.data[d] = true

                    self:_expand(r)
                end
            end
        end
    end
end

--- Performs a query against the quad tree with the provided shape.
--- @param shape slick.geometry.point | slick.geometry.rectangle
function quadTreeQuery:perform(shape)
    if util.is(shape, point) then
        --- @cast shape slick.geometry.point
        self:_performPointQuery(nil, shape)
    elseif util.is(shape, rectangle) then
        --- @cast shape slick.geometry.rectangle
        self:_performRectangleQuery(nil, shape)
    else
        -- TODO add ray
        error("unhandled shape type in query; expected point or rectangle", 2)
    end

    self:_endQuery()

    return #self.results > 0
end

return quadTreeQuery
