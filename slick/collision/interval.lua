local slicktable = require "slick.util.slicktable"

--- @alias slick.collision.intervalIndex {
---     value: number,
---     index: number,
--- }

--- @class slick.collision.interval
--- @field min number
--- @field max number
--- @field indexCount number
--- @field indices slick.collision.intervalIndex[]
--- @field private indicesCache slick.collision.intervalIndex[]
local interval = {}
local metatable = { __index = interval }

--- @return slick.collision.interval
function interval.new()
    return setmetatable({ indices = {}, indicesCache = {}, minIndex = 0, maxIndex = 0 }, metatable)
end

function interval:init()
    self.min = nil
    self.max = nil
    self.minIndex = 0
    self.maxIndex = 0
    slicktable.clear(self.indices)
end

--- @return number
--- @return number
function interval:get()
    return self.min or 0, self.max or 0
end

--- @param value number
function interval:update(value, index)
    self.min = math.min(self.min or value, value)
    self.max = math.max(self.max or value, value)

    local i = #self.indices + 1
    local indexInfo = self.indicesCache[i]
    if not indexInfo then
        indexInfo = {}
        self.indicesCache[i] = indexInfo
    end

    indexInfo.index = index
    indexInfo.value = value

    table.insert(self.indices, indexInfo)
end

local function _lessIntervalIndex(a, b)
    return a.value < b.value
end

function interval:sort()
    table.sort(self.indices, _lessIntervalIndex)

    for i, indexInfo in ipairs(self.indices) do
        if indexInfo.value >= self.min and self.minIndex == 0 then
            self.minIndex = i
        end

        if indexInfo.value <= self.max and indexInfo.value >= self.min then
            self.maxIndex = i
        end
    end
end

--- @param other slick.collision.interval
function interval:copy(other)
    other.min = self.min
    other.max = self.max
    other.minIndex = self.minIndex
    other.maxIndex = self.maxIndex

    slicktable.clear(other.indices)
    for i, selfIndexInfo in ipairs(self.indices) do
        local otherIndexInfo = other.indicesCache[i]
        if not otherIndexInfo then
            otherIndexInfo = {}
            table.insert(other.indicesCache, otherIndexInfo)
        end

        otherIndexInfo.index = selfIndexInfo.index
        otherIndexInfo.value = selfIndexInfo.value

        table.insert(other.indices, otherIndexInfo)
    end
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
