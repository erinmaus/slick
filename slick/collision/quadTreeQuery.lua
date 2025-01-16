local point = require("slick.geometry.point")
local ray = require("slick.geometry.ray")
local rectangle = require("slick.geometry.rectangle")
local segment = require("slick.geometry.segment")
local util = require("slick.util")
local slicktable = require("slick.util.slicktable")
local slickmath = require("slick.util.slickmath")

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
--- @param E number
function quadTreeQuery:_performPointQuery(node, p, E)
    if not node then
        node = self.tree.root
        self:_beginQuery()
    end

    if slickmath.withinRange(p.x, node:left(), node:right(), E) and slickmath.withinRange(p.y, node:top(), node:bottom(), E) then
        if #node.children > 0 then
            for _, c in ipairs(node.children) do
                self:_performPointQuery(c, p, E)
            end
        else
            for _, d in ipairs(node.data) do
                --- @diagnostic disable-next-line: invisible
                local r = self.tree.data[d]
                if not self.data[d] and slickmath.withinRange(p.x, r:left(), r:right(), E) and slickmath.withinRange(p.y, r:top(), r:bottom(), E) then
                    table.insert(self.results, d)
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

local _cachedQuerySegment = segment.new()

--- @private
--- @param node slick.collision.quadTreeNode?
--- @param s slick.geometry.segment
--- @param E number
function quadTreeQuery:_performSegmentQuery(node, s, E)
    if not node then
        node = self.tree.root
        self:_beginQuery()
    end

    local overlaps = (s:left() <= node:right() + E and s:right() + E >= node:left()) and
                     (s:top() <= node:bottom() + E and s:bottom() + E >= node:top())
    if overlaps then
        if #node.children > 0 then
            for _, c in ipairs(node.children) do
                self:_performSegmentQuery(c, s, E)
            end
        else
            for _, d in ipairs(node.data) do
                --- @diagnostic disable-next-line: invisible
                local r = self.tree.data[d]

                local intersection

                -- Top
                _cachedQuerySegment.a:init(r:left(), r:top())
                _cachedQuerySegment.b:init(r:right(), r:top())
                intersection = slickmath.intersection(s.a, s.b, _cachedQuerySegment.a, _cachedQuerySegment.b, E)

                if not intersection then
                    -- Right
                    _cachedQuerySegment.a:init(r:right(), r:top())
                    _cachedQuerySegment.b:init(r:right(), r:bottom())
                    intersection = slickmath.intersection(s.a, s.b, _cachedQuerySegment.a, _cachedQuerySegment.b, E)
                end

                if not intersection then
                    -- Bottom
                    _cachedQuerySegment.a:init(r:right(), r:bottom())
                    _cachedQuerySegment.b:init(r:left(), r:bottom())
                    intersection = slickmath.intersection(s.a, s.b, _cachedQuerySegment.a, _cachedQuerySegment.b, E)
                end

                if not intersection then
                    -- Left
                    _cachedQuerySegment.a:init(r:left(), r:bottom())
                    _cachedQuerySegment.b:init(r:left(), r:top())
                    intersection = slickmath.intersection(s.a, s.b, _cachedQuerySegment.a, _cachedQuerySegment.b, E)
                end

                if intersection or (r:inside(s.a) or r:inside(s.b)) then
                    table.insert(self.results, d)
                    self.data[d] = true

                    self:_expand(r)
                end
            end
        end
    end
end

--- @private
--- @param node slick.collision.quadTreeNode?
--- @param r slick.geometry.ray
function quadTreeQuery:_performRayQuery(node, r)
    if not node then
        node = self.tree.root
        self:_beginQuery()
    end

    if r:hitRectangle(node.bounds) then
        if #node.children > 0 then
            for _, c in ipairs(node.children) do
                self:_performRayQuery(c, r)
            end
        else
            for _, d in ipairs(node.data) do
                --- @diagnostic disable-next-line: invisible
                local bounds = self.tree.data[d]

                if r:hitRectangle(bounds) then
                    table.insert(self.results, d)
                    self.data[d] = true

                    self:_expand(bounds)
                end
            end
        end
    end
end

--- Performs a query against the quad tree with the provided shape.
--- @param shape slick.geometry.point | slick.geometry.rectangle | slick.geometry.segment | slick.geometry.ray
--- @param E number?
function quadTreeQuery:perform(shape, E)
    E = E or 0

    if util.is(shape, point) then
        --- @cast shape slick.geometry.point
        self:_performPointQuery(nil, shape, E)
    elseif util.is(shape, rectangle) then
        --- @cast shape slick.geometry.rectangle
        self:_performRectangleQuery(nil, shape)
    elseif util.is(shape, segment) then
        --- @cast shape slick.geometry.segment
        self:_performSegmentQuery(nil, shape, E)
    elseif util.is(shape, ray) then
        --- @cast shape slick.geometry.ray
        self:_performRayQuery(nil, shape)
    else
        error("unhandled shape type in query; expected point, rectangle, segment, or ray", 2)
    end

    self:_endQuery()

    return #self.results > 0
end

return quadTreeQuery
