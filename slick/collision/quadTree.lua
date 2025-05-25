local quadTreeNode = require("slick.collision.quadTreeNode")
local point = require("slick.geometry.point")
local rectangle = require("slick.geometry.rectangle")
local util = require("slick.util")
local pool = require("slick.util.pool")
local slicktable = require("slick.util.slicktable")

--- @class slick.collision.quadTree
--- @field root slick.collision.quadTreeNode
--- @field expand boolean
--- @field private depth number? **internal**
--- @field private nodesPool slick.util.pool **internal**
--- @field private rectanglesPool slick.util.pool **internal**
--- @field private data table<any, slick.geometry.rectangle> **internal**
--- @field bounds slick.geometry.rectangle
--- @field maxLevels number
--- @field maxData number
local quadTree = {}
local metatable = { __index = quadTree }

--- @class slick.collision.quadTreeOptions
--- @field x number?
--- @field y number?
--- @field width number?
--- @field height number?
--- @field maxLevels number?
--- @field maxData number?
--- @field expand boolean?
local defaultOptions = {
    x = -1024,
    y = -1024,
    width = 2048,
    height = 2048,
    maxLevels = 8,
    maxData = 8,
    expand = true
}

--- @param options slick.collision.quadTreeOptions?
--- @return slick.collision.quadTree
function quadTree.new(options)
    options = options or defaultOptions

    assert((options.width or defaultOptions.width) > 0, "width must be greater than 0")
    assert((options.height or defaultOptions.height) > 0, "height must be greater than 0")

    local result = setmetatable({
        maxLevels = options.maxLevels or defaultOptions.maxLevels,
        maxData = options.maxData or defaultOptions.maxData,
        expand = options.expand == nil and defaultOptions.expand or not not options.expand,
        depth = 1,
        bounds = rectangle.new(
            (options.x or defaultOptions.x),
            (options.y or defaultOptions.y),
            (options.x or defaultOptions.x) + (options.width or defaultOptions.width),
            (options.y or defaultOptions.y) + (options.height or defaultOptions.height)
        ),
        nodesPool = pool.new(quadTreeNode),
        rectanglesPool = pool.new(rectangle),
        data = {}
    }, metatable)

    result.root = result:_newNode(nil, result:left(), result:top(), result:right(), result:bottom())

    return result
end

--- Rebuilds the quad tree with the new options, preserving all existing data.
--- All options will be set to the new options, if set.
--- @param options slick.collision.quadTreeOptions
function quadTree:rebuild(options)
    --- @diagnostic disable-next-line: invisible
    self.root:_snip() -- this method is internal, not private
    self.nodesPool:deallocate(self.root)

    assert(options.width == nil or options.width > 0, "width must be greater than 0")
    assert(options.height == nil or options.height > 0, "height must be greater than 0")

    local x = options.x or self.bounds:left()
    local y = options.y or self.bounds:top()
    local width = options.width or self.bounds:width()
    local height = options.height or self.bounds:height()

    self.maxLevels = options.maxLevels or self.maxLevels
    self.maxData = options.maxData or self.maxData

    if options.expand ~= nil then
        self.expand = options.expand
    end

    self.bounds:init(x, y, x + width, y + height)
    self.root = self:_newNode(nil, self.bounds:left(), self.bounds:top(), self.bounds:right(), self.bounds:bottom())

    for data, r in pairs(self.data) do
        self:_tryExpand(r)
        self.root:insert(data, r)
    end
end

function quadTree:clear()
    for data, r in pairs(self.data) do
        self.root:remove(data, r)
        self.rectanglesPool:deallocate(r)
    end

    slicktable.clear(self.data)
end

--- Returns the exact bounds of all data in the quad tree.
--- @return number x1
--- @return number y1
--- @return number x2
--- @return number y2
function quadTree:computeExactBounds()
    local left, right, top, bottom

    for _, r in pairs(self.data) do
        left = math.min(left or r:left(), r:left())
        right = math.max(right or r:right(), r:right())
        top = math.min(top or r:top(), r:top())
        bottom = math.max(bottom or r:bottom(), r:bottom())
    end

    return left, top, right, bottom
end

--- Returns the maximum left of the quad tree.
--- @return number
function quadTree:left()
    return self.bounds:left()
end

--- Returns the maximum right of the quad tree.
--- @return number
function quadTree:right()
    return self.bounds:right()
end

--- Returns the maximum top of the quad tree.
--- @return number
function quadTree:top()
    return self.bounds:top()
end

--- Returns the maximum bottom of the quad tree.
--- @return number
function quadTree:bottom()
    return self.bounds:bottom()
end

--- Returns true if quad tree has `data`
--- @param data any
--- @return boolean
function quadTree:has(data)
    return self.data[data] ~= nil
end

--- @private
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return slick.geometry.rectangle
function quadTree:_newRectangle(x1, y1, x2, y2)
    --- @type slick.geometry.rectangle
    return self.rectanglesPool:allocate(x1, y1, x2, y2)
end

--- @private
--- @param parent slick.collision.quadTreeNode?
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return slick.collision.quadTreeNode
function quadTree:_newNode(parent, x1, y1, x2, y2)
    --- @type slick.collision.quadTreeNode
    return self.nodesPool:allocate(self, parent, x1, y1, x2, y2)
end

local _cachedInsertRectangle = rectangle.new()

--- @overload fun(rectangle: slick.geometry.rectangle)
--- @overload fun(p: slick.geometry.rectangle, width: number?, height: number?)
--- @overload fun(p1: slick.geometry.point, p2: slick.geometry.point?)
--- @overload fun(x1: number?, y1: number?, x2: number?, y2: number?)
local function _getRectangle(a, b, c, d)
    --- @type slick.geometry.rectangle
    local r
    if util.is(a, rectangle) then
        --- @cast a slick.geometry.rectangle
        r = a
    elseif util.is(a, point) then
        r = _cachedInsertRectangle
        if b and util.is(b, point) then
            r:init(a.x, a.y, b.x, b.y)
        else
            r:init(a.x, a.y, (a.x + (b or 0)), (a.y + (c or 0)))
        end
    else
        r = _cachedInsertRectangle

        --- @cast a number
        --- @cast b number
        r:init(a, b, c, d)
    end

    return r
end

--- @private
--- @param r slick.geometry.rectangle
function quadTree:_tryExpand(r)
    if r:overlaps(self.bounds) then
        return
    end

    if not self.expand then
        error("shape is completely outside of quad tree and quad tree is not set to auto-expand", 3)
        return
    end

    while not r:overlaps(self.bounds) do
        self.maxLevels = self.maxLevels + 1
        self.root = self.root:expand(r)
        
        self.bounds:init(self.root:left(), self.root:top(), self.root:right(), self.root:bottom())
    end
end

--- Inserts `data` into the tree using the provided bounds.
--- 
--- `data` must **not** be in the tree already; if it is, this method will raise an error.
--- Instead, use `quadTree.update` to move (or insert) an object.
--- @param data any
--- @overload fun(self: slick.collision.quadTree, data: any, rectangle: slick.geometry.rectangle)
--- @overload fun(self: slick.collision.quadTree, data: any, p: slick.geometry.rectangle, width: number?, height: number?)
--- @overload fun(self: slick.collision.quadTree, data: any, p1: slick.geometry.point, p2: slick.geometry.point?)
--- @overload fun(self: slick.collision.quadTree, data: any, x1: number?, y1: number?, x2: number?, y2: number?)
--- @return slick.collision.quadTree
function quadTree:insert(data, a, b, c, d)
    assert(not self.data[data], "data needs to be removed before inserting or use update")
    
    local r = _getRectangle(a, b, c, d)
    self:_tryExpand(r)

    self.data[data] = self:_newRectangle(r:left(), r:top(), r:right(), r:bottom())
    self.root:insert(data, r)
end

--- Removes `data` from the tree.
--- 
--- `data` **must** be in the tree already; if it is not, this method will raise an assert.
--- @param data any
function quadTree:remove(data)
    assert(self.data[data] ~= nil)

    local r = self.data[data]
    self.data[data] = nil

    self.root:remove(data, r)
    self.rectanglesPool:deallocate(r)
end

--- Updates `data` with new bounds.
--- 
--- This essentially safely does a `remove` then `insert`.
--- @param data any
--- @overload fun(self: slick.collision.quadTree, data: any, rectangle: slick.geometry.rectangle)
--- @overload fun(self: slick.collision.quadTree, data: any, p: slick.geometry.rectangle, width: number?, height: number?)
--- @overload fun(self: slick.collision.quadTree, data: any, p1: slick.geometry.point, p2: slick.geometry.point?)
--- @overload fun(self: slick.collision.quadTree, data: any, x1: number?, y1: number?, x2: number?, y2: number?)
--- @see slick.collision.quadTree.insert
--- @see slick.collision.quadTree.remove
function quadTree:update(data, a, b, c, d)
    if self.data[data] then
        self:remove(data)
    end

    self:insert(data, a, b, c, d)
end

return quadTree
