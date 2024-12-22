return {
    math = require("slick.util.slickmath"),
    pool = require("slick.util.pool"),
    search = require("slick.util.search"),
    table = require("slick.util.slicktable"),
    is = function(obj, t)
        return type(obj) == "table" and getmetatable(obj) and getmetatable(obj).__index == t
    end
}
