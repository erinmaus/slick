local slick = require("slick")
local test = require("test.common.test")

test("line segment normals should be correct", function(t)
    local world = slick.newWorld(192, 192)

    local segment = {}
    world:add(segment, 0, 0, slick.newLineSegmentShape(162, 156, 162, 162))

    local player = {}
    world:add(player, 150, 154, slick.newCircleShape(0, 0, 0.5))

    local topBottomCols = world:project(player, 162, 155, 162, 162, function() return true end)
    assert(#topBottomCols == 1, "expected one top-to-bottom collision")
    print("touch", topBottomCols[1].touch.x, topBottomCols[1].touch.y)
    assert(topBottomCols[1].normal.x == 0 and topBottomCols[1].normal.y == -1, "expected collision normal from top-to-bottom to be (0, -1)")

    local bottomTopCols = world:project(player, 162, 163, 162, 159, function() return true end)
    assert(#bottomTopCols == 1, "expected one bottom-to-top collision")
    print("normal", bottomTopCols[1].normal.x, bottomTopCols[1].normal.y)
    assert(bottomTopCols[1].normal.x == 0 and bottomTopCols[1].normal.y == 1, "expected collision normal from bottom-to-top to be (0, 1)")

    local rightLeftCols = world:project(player, 162.5, 159, 161, 163, function() return true end)
    assert(#rightLeftCols == 1, "expected one right-to-left collision")
    assert(rightLeftCols[1].normal.x == 1 and rightLeftCols[1].normal.y == 0, "expected collision normal from right-to-left to be (1, 0)")

    local leftRightCols = world:project(player, 160.5, 159, 162.5, 160, function() return true end)
    print("#", #leftRightCols)
    assert(#leftRightCols == 1, "expected one left-to-right collision")
    assert(leftRightCols[1].normal.x == -1 and leftRightCols[1].normal.y == 0, "expected collision normal from right-to-left to be (-1, 0)")
end)