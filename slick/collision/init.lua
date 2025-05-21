--- @alias slick.collision.shapeInterface slick.collision.commonShape

--- @alias slick.collision.shape slick.collision.polygon | slick.collision.box | slick.collision.commonShape
--- @alias slick.collision.shapelike slick.collision.shape | slick.collision.shapeGroup | slick.collision.shapeInterface | slick.collision.polygonMesh

local collision = {
    quadTree = require("slick.collision.quadTree"),
    quadTreeNode = require("slick.collision.quadTreeNode"),
    quadTreeQuery = require("slick.collision.quadTreeQuery"),
    polygon = require("slick.collision.polygon"),
    shapeCollisionResolutionQuery = require("slick.collision.shapeCollisionResolutionQuery"),
}

return collision
