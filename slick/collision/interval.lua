--- @class slick.collision.interval
--- @field min number
--- @field max number
local interval = {}
local metatable = { __index = interval }

--- @return slick.collision.interval
function interval.new()
    return setmetatable({}, metatable)
end

function interval:init()
    self.min = nil
    self.max = nil
end

--- @return number
--- @return number
function interval:get()
    return self.min or 0, self.max or 0
end

--- @param value number
function interval:update(value)
    self.min = math.min(self.min or value, value)
    self.max = math.max(self.max or value, value)
end

--- @param min number
--- @param max number
function interval:set(min, max)
    assert(min <= max)

    self.min = min
    self.max = max
end

function interval:overlaps(other)
    return not (self.min > other.max or other.min > self.max)
end

function interval:distance(other)
    if self:overlaps(other) then
        return math.min(self.max, other.max) - math.max(self.min, other.min)
    else
        return 0
    end
end

function interval:contains(other)
    return other.min > self.min and other.max < self.max
end

return interval
