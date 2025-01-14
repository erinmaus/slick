local slicktable = require("slick.util.slicktable")

--- @class slick.util.pool
--- @field type { new: function }
--- @field used table
--- @field free table
local pool = {}
local metatable = { __index = pool }

--- Constructs a new pool for the provided type.
--- @param poolType any
--- @return slick.util.pool
function pool.new(poolType)
    return setmetatable({
        type = poolType,
        used = {},
        free = {}
    }, metatable)
end

--- Allocates a new type, initializing the new instance with the provided arguments.
--- @param ... any arguments to pass to the new instance
--- @return any 
function pool:allocate(...)
    local result
    if #self.free == 0 then
        result = self.type and self.type.new() or {}
        if self.type then
            result:init(...)
        end
        
        self.used[result] = true
    else
        result = table.remove(self.free, #self.free)
        if self.type then
            result:init(...)
        end

        self.used[result] = true
    end
    return result
end

--- Returns an instance to the pool.
--- @param t any the type to return to the pool
function pool:deallocate(t)
    self.used[t] = nil
    table.insert(self.free, t)
end

--- Moves all used instances to the free instance list.
--- Anything returned by allocate is no longer considered valid - the instance may be reused.
--- @see slick.util.pool.allocate
function pool:reset()
    for v in pairs(self.used) do
        self:deallocate(v)
    end
end

--- Clears all tracking for free and used instances.
function pool:clear()
    slicktable.clear(self.used)
    slicktable.clear(self.free)
end

return pool
