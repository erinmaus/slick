local slicktable = require("slick.util.slicktable")
local util = require("slick.util.common")

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

--- Removes `value` from this pool's scope. `value` will not be re-used.
--- Only removing allocated (**not free!**) values is permitted. If `value` is in the free list,
--- this will fail and return false.
--- @param value any
--- @return boolean result true if `value` was removed from this pool, false otherwise
function pool:remove(value)
    if self.used[value] then
        self.used[value] = nil
        return true
    end

    return false
end

--- Adds `value` to this pool's scope. Behavior is undefined if `value` belongs to another pool.
--- If `value` is not exactly of the type this pool manages then it will not be added to this pool.
--- @param value any
--- @return boolean result true if `value` was added to this pool, false otherwise
function pool:add(value)
    if util.is(value, self.type) then
        self.used[value] = true
        return true
    end

    return false
end

--- Moves `value` from the source pool to the target pool.
--- This effective removes `value` from `source` and adds `value` to `target`
--- @param source slick.util.pool
--- @param target slick.util.pool
--- @param value any
--- @return boolean result true if `value` was moved successfully, `false` otherwise
--- @see slick.util.pool.add
--- @see slick.util.pool.remove
function pool.swap(source, target, value)
    return source:remove(value) and target:add(value)
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
