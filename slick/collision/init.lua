--- @alias slick.collision.shapeInterface {
---     entity: slick.entity,
---     vertexCount: number,
---     normalCount: number,
---     center: slick.geometry.point,
---     vertices: slick.geometry.point[],
---     normals: slick.geometry.point[],
---     bounds: slick.geometry.rectangle,
---     transform: fun(self: slick.collision.shapeInterface, transform: slick.geometry.transform),
---     getAxes: fun(self: slick.collision.shapeInterface, query: slick.collision.shapeCollisionResolutionQueryShape),
---     getAxes: fun(self: slick.collision.shapeInterface, query: slick.collision.shapeCollisionResolutionQueryShape),
---     distance: fun(self: slick.collision.shapeInterface, p: slick.geometry.point)
--- }

--- @alias slick.collision.shape slick.collision.circle | slick.collision.polygon
--- @alias slick.collision.shapelike slick.collision.shape | slick.collision.shapeGroup | slick.collision.shapeInterface

local collision = {
    circle = require("slick.collision.circle"),
    quadTree = require("slick.collision.quadTree"),
    quadTreeNode = require("slick.collision.quadTreeNode"),
    quadTreeQuery = require("slick.collision.quadTreeQuery"),
    polygon = require("slick.collision.polygon"),
    shapeCollisionResolutionQuery = require("slick.collision.shapeCollisionResolutionQuery"),
}

return collision
