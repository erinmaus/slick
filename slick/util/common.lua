return {
    is = function(obj, t)
        return type(t) == "table" and type(obj) == "table" and getmetatable(obj) and getmetatable(obj).__index == t
    end,

    type = function(obj)
        return type(obj) == "table" and getmetatable(obj) and getmetatable(obj).__index
    end
}
