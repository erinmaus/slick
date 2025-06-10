local segment = require("slick.geometry.segment")
local edge = require("slick.geometry.triangulation.edge")

--- @class slick.geometry.triangulation.delaunaySortedEdge
--- @field edge slick.geometry.triangulation.edge
--- @field segment slick.geometry.segment
local delaunaySortedEdge = {}
local metatable = { __index = delaunaySortedEdge }

--- @return slick.geometry.triangulation.delaunaySortedEdge
function delaunaySortedEdge.new()
    return setmetatable({
        edge = edge.new(),
        segment = segment.new()
    }, metatable)
end

--- @param a slick.geometry.triangulation.delaunaySortedEdge
--- @param b slick.geometry.triangulation.delaunaySortedEdge
--- @return slick.util.search.compareResult
function delaunaySortedEdge.compare(a, b)
    return segment.compare(a.segment, b.segment, 0)
end

--- @param sortedEdge slick.geometry.triangulation.delaunaySortedEdge
--- @param segment slick.geometry.segment
--- @return slick.util.search.compareResult
function delaunaySortedEdge.compareSegment(sortedEdge, segment)
    return segment.compare(sortedEdge.segment, segment, 0)
end

--- @param a slick.geometry.triangulation.delaunaySortedEdge
--- @param b slick.geometry.triangulation.delaunaySortedEdge
--- @return boolean
function delaunaySortedEdge.less(a, b)
    return delaunaySortedEdge.compare(a, b) < 0
end

--- @param e slick.geometry.triangulation.edge
--- @param segment slick.geometry.segment
function delaunaySortedEdge:init(e, segment)
    self.edge:init(e.a, e.b)
    self.segment:init(segment.a, segment.b)
end

return delaunaySortedEdge
