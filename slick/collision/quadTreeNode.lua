local rectangle = require("slick.geometry.rectangle")
local slicktable = require("slick.util.slicktable")

--- @class slick.collision.quadTreeNode
--- @field tree slick.collision.quadTree
--- @field level number
--- @field count number
--- @field parent slick.collision.quadTreeNode?
--- @field children slick.collision.quadTreeNode[]
--- @field data any[]
--- @field private uniqueData table<any, boolean>
--- @field bounds slick.geometry.rectangle
local quadTreeNode = {}
local metatable = { __index = quadTreeNode }

--- @return slick.collision.quadTreeNode
function quadTreeNode.new()
    return setmetatable({
        level = 0,
        bounds = rectangle.new(),
        count = 0,
        children = {},
        data = {},
        uniqueData = {}
    }, metatable)
end

--- @param tree slick.collision.quadTree
--- @param parent slick.collision.quadTreeNode?
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
function quadTreeNode:init(tree, parent, x1, y1, x2, y2)
    self.tree = tree
    self.parent = parent
    self.level = (parent and parent.level or 0) + 1
    self.depth = self.level
    self.bounds:init(x1, y1, x2, y2)

    slicktable.clear(self.children)
    slicktable.clear(self.data)
    slicktable.clear(self.uniqueData)
end

--- @private
--- @param parent slick.collision.quadTreeNode?
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return slick.collision.quadTreeNode
function quadTreeNode:_newNode(parent, x1, y1, x2, y2)
    --- @diagnostic disable-next-line: invisible
    return self.tree:_newNode(parent, x1, y1, x2, y2)
end

--- Returns the maximum left of the quad tree.
--- @return number
function quadTreeNode:left()
    return self.bounds:left()
end

--- Returns the maximum right of the quad tree.
--- @return number
function quadTreeNode:right()
    return self.bounds:right()
end

--- Returns the maximum top of the quad tree.
--- @return number
function quadTreeNode:top()
    return self.bounds:top()
end

--- Returns the maximum bottom of the quad tree.
--- @return number
function quadTreeNode:bottom()
    return self.bounds:bottom()
end

--- @private
--- @param node slick.collision.quadTreeNode
function quadTreeNode._incrementLevel(node)
    node.level = node.level + 1
end

--- Visits all nodes, including this one, calling `func` on the node.
--- @param func fun(node: slick.collision.quadTreeNode)
function quadTreeNode:visit(func)
    func(self)
    
    for _, c in ipairs(self.children) do
        c:visit(func)
    end
end

--- @private
--- @param func fun(node: slick.collision.quadTreeNode)
--- @param ignore slick.collision.quadTreeNode
function quadTreeNode:_visit(func, ignore)
    if self == ignore then
        return
    end

    func(self)
    
    for _, c in ipairs(self.children) do
        c:visit(func)
    end
end

--- Visits all parent nodes and their children, calling `func` on the node.
--- This method iterates from the parent node down, skipping the node `ascend` was called on.
--- @param func fun(node: slick.collision.quadTreeNode)
function quadTreeNode:ascend(func)
    if self.tree.root ~= self then
        self.tree.root:_visit(func, self)
    end
end

--- Expands this node to fit 'bounds'.
--- @param bounds slick.geometry.rectangle
--- @return slick.collision.quadTreeNode
function quadTreeNode:expand(bounds)
    assert(not self.parent, "can only expand root node")
    assert(not bounds:overlaps(self.bounds), "bounds is within quad tree")

    local halfWidth = (self:right() - self:left()) / 2
    local halfHeight = (self:bottom() - self:top()) / 2

    local x1, x2
    local left, right = false, false
    if bounds:right() < self:left() + halfWidth then
        left = true

        x1 = self:left() - halfWidth
        x2 = self:right() + halfWidth
    else
        right = true

        x1 = self:right() - halfWidth
        x2 = self:right() + halfWidth
    end

    local y1, y2
    local top, bottom = false, false
    if bounds:bottom() < self:top() + halfHeight then
        top = true

        y1 = self:top() - halfHeight
        y2 = self:bottom() + halfHeight
    else
        bottom = true

        y1 = self:bottom() - halfHeight
        y2 = self:bottom() + halfHeight
    end

    local parent = self:_newNode(nil, x1, y1, x2, y2)
    local topLeft, topRight, bottomLeft, bottomRight
    if top and left then
        topLeft = self
        topRight = self:_newNode(parent, x1 + (x2 - x1) / 2, y1, x2, y1 + (y2 - y1) / 2)
        bottomLeft = self:_newNode(parent, x1, y1 + (y2 - y1) / 2, x1 + (x2 - x1) / 2, y2)
        bottomRight = self:_newNode(parent, x1 + (x2 - x1) / 2, y1 + (y2 - y1) / 2, x2, y2)
    elseif top and right then
        topLeft = self:_newNode(parent, x1, y1, x1 + (x2 - x1) / 2, y1 + (y2 - y1) / 2)
        topRight = self
        bottomLeft = self:_newNode(parent, x1, y1 + (y2 - y1) / 2, x1 + (x2 - x1) / 2, y2)
        bottomRight = self:_newNode(parent, x1 + (x2 - x1) / 2, y1 + (y2 - y1) / 2, x2, y2)
    elseif bottom and left then
        topLeft = self:_newNode(parent, x1, y1, x1 + (x2 - x1) / 2, y1 + (y2 - y1) / 2)
        topRight = self:_newNode(parent, x1 + (x2 - x1) / 2, y1, x2, y1 + (y2 - y1) / 2)
        bottomLeft = self
        bottomRight = self:_newNode(parent, x1 + (x2 - x1) / 2, y1 + (y2 - y1) / 2, x2, y2)
    elseif bottom and right then
        topLeft = self:_newNode(parent, x1, y1, x1 + (x2 - x1) / 2, y1 + (y2 - y1) / 2)
        topRight = self:_newNode(parent, x1 + (x2 - x1) / 2, y1, x2, y1 + (y2 - y1) / 2)
        bottomLeft = self:_newNode(parent, x1, y1 + (y2 - y1) / 2, x1 + (x2 - x1) / 2, y2)
        bottomRight = self
    else
        assert(false, "critical logic error")
    end

    table.insert(parent.children, topLeft)
    table.insert(parent.children, topRight)
    table.insert(parent.children, bottomLeft)
    table.insert(parent.children, bottomRight)

    self.parent = parent
    return parent
end

--- Inserts `data` given the `bounds` into this node.
--- 
--- `data` must not already be added to this node.
--- @param data any
--- @param bounds slick.geometry.rectangle
function quadTreeNode:insert(data, bounds)
    if (#self.children == 0 and #self.data < self.tree.maxData) or self.level >= self.tree.maxLevels then
        assert(self.uniqueData[data] == nil, "data is already in node")

        self.uniqueData[data] = true
        table.insert(self.data, data)

        self.count = self.count + 1

        return
    end

    if #self.children == 0 and #self.data >= self.tree.maxData then
        self.count = 0
        self:split()
    end

    for _, child in ipairs(self.children) do
        if bounds:overlaps(child.bounds) then
            child:insert(data, bounds)
        end
    end

    self.count = self.count + 1
end

--- @param data any
--- @param bounds slick.geometry.rectangle
function quadTreeNode:remove(data, bounds)
    if #self.children > 0 then
        for _, child in ipairs(self.children) do
            if bounds:overlaps(child.bounds) then
                child:remove(data, bounds)
            end
        end

        self.count = self.count - 1

        return
    end

    assert(self.uniqueData[data] ~= nil, "data is not in node")

    for i, d in ipairs(self.data) do
        if d == data then
            table.remove(self.data, i)
            self.count = self.count - 1            

            if self.parent and self.parent.count <= self.tree.maxData then
                self.parent:collapse()
            end

            return
        end
    end

    assert(false, "critical logic error: unique data set and data array de-synced")
end

--- Splits the node into children nodes.
--- Moves any data from this node to the children nodes.
function quadTreeNode:split()
    assert(#self.data >= self.tree.maxData, "cannot split; still has room")

    local width = self:right() - self:left()
    local height = self:bottom() - self:top()

    local childWidth = width / 2
    local childHeight = height / 2

    local topLeft = self:_newNode(self, self:left(), self:top(), self:left() + childWidth, self:top() + childHeight)
    local topRight = self:_newNode(self, self:left() + childWidth, self:top(), self:right(), self:top() + childHeight)
    local bottomLeft = self:_newNode(self, self:left(), self:top() + childHeight, self:left() + childWidth, self:bottom())
    local bottomRight = self:_newNode(self, self:left() + childWidth, self:top() + childHeight, self:right(), self:bottom())

    table.insert(self.children, topLeft)
    table.insert(self.children, topRight)
    table.insert(self.children, bottomLeft)
    table.insert(self.children, bottomRight)

    for _, data in ipairs(self.data) do
        --- @diagnostic disable-next-line: invisible
        local r = self.tree.data[data]
        self:insert(data, r)
    end

    slicktable.clear(self.data)
    slicktable.clear(self.uniqueData)
end

local _collectResult = { n = 0, unique = {}, data = {} }

--- @private
--- @param node slick.collision.quadTreeNode
function quadTreeNode._collect(node)
    for _, data in ipairs(node.data) do
        if not _collectResult.unique[data] then
            _collectResult.unique[data] = true
            table.insert(_collectResult.data, data)

            _collectResult.n = _collectResult.n + 1
        end
    end
end

--- @private
--- Deallocates all children nodes.
function quadTreeNode:_snip()
    for _, child in ipairs(self.children) do
        child:_snip()

        --- @diagnostic disable-next-line: invisible
        self.tree.nodesPool:deallocate(child)
    end

    slicktable.clear(self.children)
end

--- Collapses the children node into this node.
function quadTreeNode:collapse()
    _collectResult.n = 0
    slicktable.clear(_collectResult.unique)
    slicktable.clear(_collectResult.data)

    self:visit(self._collect)

    if _collectResult.n <= self.tree.maxData then
        self:_snip()

        for _, data in ipairs(_collectResult.data) do
            self.uniqueData[data] = true
            table.insert(self.data, data)
        end

        self.count = #self.data

        if self.parent and self.parent.count < self.tree.maxData then
            self.parent:collapse()
        end

        return true
    end

    return false
end

return quadTreeNode
