local delaunay = require("slick.geometry.triangulation.delaunay")

local d = delaunay.new()

-- shape 1
local shape = {
    337, 182,
    173, 518,
    173, 518,
    453, 695,
    684, 470,
    589, 208
}

-- shape 2
local edges = {
    365, 261,
    278, 452,
    407, 559,
    515, 332
}

local result = d:triangulate(shape, edges)

for _, triangle in ipairs(result) do
    print(">", triangle[1], triangle[2], triangle[3])
end

love.event.quit()
