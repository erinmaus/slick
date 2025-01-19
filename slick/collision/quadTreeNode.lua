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

--- @return number
function quadTreeNode:width()
    return self.bounds:width()
end

--- @return number
function quadTreeNode:height()
    return self.bounds:height()
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

local _cachedQuadTreeNodeData = {}

--- @param node slick.collision.quadTreeNode
local function _gatherData(node)
    for _, data in ipairs(node.data) do
        _cachedQuadTreeNodeData[data] = true
    end
end

--- Expands this node to fit 'bounds'.
--- @param bounds slick.geometry.rectangle
--- @return slick.collision.quadTreeNode
function quadTreeNode:expand(bounds)
    assert(not self.parent, "can only expand root node")
    assert(not bounds:overlaps(self.bounds), "bounds is within quad tree")
    assert(bounds:left() > -math.huge and bounds:right() < math.huge, "x axis infinite")
    assert(bounds:top() > -math.huge and bounds:bottom() < math.huge, "y axis infinite")
    
    slicktable.clear(_cachedQuadTreeNodeData)
    self:visit(_gatherData)

    local halfWidth = self:width() / 2
    local halfHeight = self:height() / 2

    local left, right = false, false
    if bounds:right() < self:left() + halfWidth then
        right = true
    else
        left = true
    end

    local top, bottom = false, false
    if bounds:bottom() < self:top() + halfHeight then
        bottom = true
    else
        top = true
    end

    local parent
    local topLeft, topRight, bottomLeft, bottomRight
    if top and left then
        parent = self:_newNode(nil, self:left(), self:top(), self:right() + self:width(), self:bottom() + self:height())
        topLeft = self
        topRight = self:_newNode(parent, self:right(), self:top(), self:right() + self:width(), self:bottom())
        bottomLeft = self:_newNode(parent, self:left(), self:bottom(), self:right(), self:bottom() + self:height())
        bottomRight = self:_newNode(parent, self:right(), self:bottom(), self:right() + self:width(), self:bottom() + self:height())
    elseif top and right then
        parent = self:_newNode(nil, self:left() - self:width(), self:top(), self:right(), self:bottom() + self:height())
        topLeft = self:_newNode(parent, self:left() - self:width(), self:top(), self:left(), self:bottom())
        topRight = self
        bottomLeft = self:_newNode(parent, self:left() - self:width(), self:bottom(), self:left(), self:bottom() + self:height())
        bottomRight = self:_newNode(parent, self:left(), self:bottom(), self:right(), self:bottom() + self:height())
    elseif bottom and left then
        parent = self:_newNode(nil, self:left(), self:top() - self:height(), self:right() + self:width(), self:bottom())
        topLeft = self:_newNode(parent, self:left(), self:top() - self:height(), self:right(), self:top())
        topRight = self:_newNode(parent, self:right(), self:top() - self:height(), self:right() + self:width(), self:top())
        bottomLeft = self
        bottomRight = self:_newNode(parent, self:right(), self:top(), self:right() + self:width(), self:bottom())
    elseif bottom and right then
        parent = self:_newNode(nil, self:left() - self:width(), self:top() - self:height(), self:right(), self:bottom())
        topLeft = self:_newNode(parent, self:left() - self:width(), self:top() - self:height(), self:left(), self:top())
        topRight = self:_newNode(parent, self:left(), self:top() - self:height(), self:right(), self:top())
        bottomLeft = self:_newNode(parent, self:left() - self:width(), self:top(), self:left(), self:bottom())
        bottomRight = self
    else
        assert(false, "critical logic error")
    end

    table.insert(parent.children, topLeft)
    table.insert(parent.children, topRight)
    table.insert(parent.children, bottomLeft)
    table.insert(parent.children, bottomRight)

    for _, child in ipairs(parent.children) do
        if child ~= self then
            for data in pairs(_cachedQuadTreeNodeData) do
                --- @diagnostic disable-next-line: invisible
                local r = self.tree.data[data]
                if r:overlaps(child.bounds) then
                    child:insert(data, r)
                end
            end
        end
    end

    self:visit(quadTreeNode._incrementLevel)

    parent.count = self.count
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

        if self.count <= self.tree.maxData then
            self:collapse()
        end

        return
    end

    if not self.uniqueData[data] then
        return
    end

    for i, d in ipairs(self.data) do
        if d == data then
            table.remove(self.data, i)
            self.count = self.count - 1

            self.uniqueData[d] = nil

            return
        end
    end
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

--- @package
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

        return true
    end

    return false
end

return quadTreeNode
