--- @alias slick.collision.shape {
---     vertexCount: number,
---     normalCount: number,
---     center: slick.geometry.point,
---     vertices: slick.geometry.point[],
---     normals: slick.geometry.point[],
---     transform: fun(self: slick.collision.shape, transform: slick.geometry.transform),
---     getAxes: fun(self: slick.collision.shape, query: slick.collision.shapeCollisionResolutionQueryShape),
---     project: fun(self: slick.collision.shape, query: slick.collision.shapeCollisionResolutionQueryShape, axis: slick.geometry.point, interval: slick.collision.interval)
--- }


local collision = {
    circle = require("slick.collision.circle"),
    quadTree = require("slick.collision.quadTree"),
    quadTreeNode = require("slick.collision.quadTreeNode"),
    quadTreeQuery = require("slick.collision.quadTreeQuery"),
    polygon = require("slick.collision.polygon"),
    shapeCollisionResolutionQuery = require("slick.collision.shapeCollisionResolutionQuery")
}

return collision
