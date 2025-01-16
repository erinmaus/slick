--- @alias slick.geometry.shape slick.geometry.point | slick.geometry.ray | slick.geometry.rectangle | slick.geometry.segment

local geometry = {
    clipper = require("slick.geometry.clipper"),
    triangulation = require("slick.geometry.triangulation"),
    point = require("slick.geometry.point"),
    ray = require("slick.geometry.ray"),
    rectangle = require("slick.geometry.rectangle"),
    segment = require("slick.geometry.segment"),
    simple = require("slick.geometry.simple"),
    transform = require("slick.geometry.transform"),
}

return geometry
