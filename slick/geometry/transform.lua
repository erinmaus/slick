local slickmath = require("slick.util.slickmath")

--- Represents a transform.
--- @class slick.geometry.transform
--- @field private immutable boolean
--- @field x number
--- @field y number
--- @field rotation number
--- @field private rotationCos number
--- @field private rotationSin number
--- @field scaleX number
--- @field scaleY number
--- @field offsetX number
--- @field offsetY number
local transform = {}
local metatable = { __index = transform }

--- Constructs a new transform.
--- @param x number? translation on the x axis (defaults to 0)
--- @param y number? translation on the y axis (defaults to 0)
--- @param rotation number? rotation in radians (defaults to 0)
--- @param scaleX number? scale along the x axis (defaults to 1)
--- @param scaleY number? scale along the y axis (defaults to 1)
--- @param offsetX number? offset along the x axis (defaults to 0)
--- @param offsetY number? offsete along the y axis (defaults to 0)
function transform.new(x, y, rotation, scaleX, scaleY, offsetX, offsetY)
    local result = setmetatable({}, metatable)
    result:setTransform(x, y, rotation, scaleX, scaleY, offsetX, offsetY)
    result.immutable = false

    return result
end

--- @package
--- @param x number? translation on the x axis (defaults to 0)
--- @param y number? translation on the y axis (defaults to 0)
--- @param rotation number? rotation in radians (defaults to 0)
--- @param scaleX number? scale along the x axis (defaults to 1)
--- @param scaleY number? scale along the y axis (defaults to 1)
--- @param offsetX number? offset along the x axis (defaults to 0)
--- @param offsetY number? offsete along the y axis (defaults to 0)
function transform._newImmutable(x, y, rotation, scaleX, scaleY, offsetX, offsetY)
    local result = setmetatable({}, metatable)
    result:setTransform(x, y, rotation, scaleX, scaleY, offsetX, offsetY)
    result.immutable = true

    return result
end

--- Same as setTransform.
--- @param x number? translation on the x axis
--- @param y number? translation on the y axis
--- @param rotation number? rotation in radians
--- @param scaleX number? scale along the x axis
--- @param scaleY number? scale along the y axis
--- @param offsetX number? offset along the x axis
--- @param offsetY number? offsete along the y axis
--- @see slick.geometry.transform.setTransform
function transform:init(x, y, rotation, scaleX, scaleY, offsetX, offsetY)
    self:setTransform(x, y, rotation, scaleX, scaleY, offsetX, offsetY)
end

--- Constructs a transform.
--- @param x number? translation on the x axis
--- @param y number? translation on the y axis
--- @param rotation number? rotation in radians
--- @param scaleX number? scale along the x axis
--- @param scaleY number? scale along the y axis
--- @param offsetX number? offset along the x axis
--- @param offsetY number? offsete along the y axis
function transform:setTransform(x, y, rotation, scaleX, scaleY, offsetX, offsetY)
    self.x = x or self.x or 0
    self.y = y or self.y or 0
    self.rotation = rotation or self.rotation or 0
    self.rotationCos = math.cos(self.rotation)
    self.rotationSin = math.sin(self.rotation)
    self.scaleX = scaleX or self.scaleX or 1
    self.scaleY = scaleY or self.scaleY or 1
    self.offsetX = offsetX or self.offsetX or 0
    self.offsetY = offsetY or self.offsetY or 0
end

--- Transforms (x, y) by the transform and returns the transformed coordinates.
--- @param x number
--- @param y number
--- @return number x
--- @return number y
function transform:transformPoint(x, y)
    local ox = x - self.offsetX
    local oy = y - self.offsetY
    local rx = ox * self.rotationCos - oy * self.rotationSin
    local ry = ox * self.rotationSin + oy * self.rotationCos
    local sx = rx * self.scaleX
    local sy = ry * self.scaleY
    local resultX = sx + self.x
    local resultY = sy + self.y

    return resultX, resultY
end

--- Transforms the normal (x, y) by this transform.
--- This is essentially the inverse-transpose of just the rotation and scale components.
--- @param x number
--- @param y number
--- @return number x
--- @return number y
function transform:transformNormal(x, y)
    local sx = x / self.scaleX
    local sy = y / self.scaleY
    local resultX = sx * self.rotationCos - sy * self.rotationSin
    local resultY = sx * self.rotationSin + sy * self.rotationCos

    return resultX, resultY
end

--- Transforms (x, y) by the inverse of the transform and returns the inverse transformed coordinates.
--- @param x number
--- @param y number
--- @return number x
--- @return number y
function transform:inverseTransformPoint(x, y)
    local tx = x - self.x
    local ty = y - self.y
    local sx = tx / self.scaleX
    local sy = ty / self.scaleY
    local rx = sx * self.rotationCos + sy * self.rotationSin
    local ry = sy * self.rotationCos - sx * self.rotationSin
    local resultX = rx + self.offsetX
    local resultY = ry + self.offsetY

    return resultX, resultY
end

--- Copies this transform to `other`.
--- @param other slick.geometry.transform
function transform:copy(other)
    assert(not other.immutable)

    other.x = self.x
    other.y = self.y
    other.rotation = self.rotation
    other.rotationCos = self.rotationCos
    other.rotationSin = self.rotationSin
    other.scaleX = self.scaleX
    other.scaleY = self.scaleY
    other.offsetX = self.offsetX
    other.offsetY = self.offsetY
end

transform.IDENTITY = transform._newImmutable()

return transform
