local point = require("slick.geometry.point")
local slickmath = require("slick.util.slickmath")

--- @class slick.geometry.clipper.merge
--- @field source "subject" | "other"
--- @field target "subject" | "other"
--- @field sourceIndex number
--- @field sourceUserdata any
--- @field resultIndex number
--- @field resultUserdata any
local merge = {}
local metatable = { __index = merge }

--- @return slick.geometry.clipper.merge
function merge.new()
    return setmetatable({}, metatable)
end

--- @param source "subject" | "other"
--- @param sourceIndex number
--- @param sourceUserdata any
--- @param resultIndex number
function merge:init(source, sourceIndex, sourceUserdata, resultIndex)
    self.source = source
    if source == "subject" then
        self.target = "other"
    else
        self.target = "subject"
    end

    self.sourceIndex = sourceIndex
    self.sourceUserdata = sourceUserdata
    self.resultIndex = resultIndex
    self.resultUserdata = nil
end

--- @param m slick.geometry.clipper.merge
function merge.default(m)
    -- No-op.
end

return merge
