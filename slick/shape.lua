local circle = require("slick.collision.circle")
local polygon = require("slick.collision.polygon")
local polygonMesh = require("slick.collision.polygonMesh")

--- @alias slick.collision.shapeDefinition {
---     type: { new: fun(entity: slick.entity, ...: any): slick.collision.shape },
---     n: number,
---     arguments: table,
--- }

--- @param ... number[] a list of x, y coordinates in the form `{ x1, y1, x2, y2, ..., xn, yn }`
--- @return slick.collision.shapeDefinition
local function newPolygonMesh(...)
    return {
        type = polygonMesh,
        n = select("#", ...),
        arguments = { ... }
    }
end

--- @param vertices number[] a list of x, y coordinates in the form `{ x1, y1, x2, y2, ..., xn, yn }`
--- @return slick.collision.shapeDefinition
local function newPolygon(vertices)
    return {
        type = polygon,
        n = 1,
        arguments = { vertices }
    }
end

--- @param x number
--- @param y number
--- @param radius number
--- @return slick.collision.shapeDefinition
local function newCircle(x, y, radius)
    return {
        type = circle,
        n = 3,
        arguments = { x, y, radius }
    }
end

return {
    newCircle = newCircle,
    newPolygon = newPolygon,
    newPolygonMesh = newPolygonMesh,
}
