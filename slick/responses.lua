--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param filter slick.worldFilterQueryFunc
--- @return number, number, slick.worldQueryResponse[], number, slick.worldQuery
local function slide(world, query, response, x, y, filter)
    if response.time > 0 and response.time < 1 then
        x = x + response.offset.x
        y = y + response.offset.y
    elseif response.depth > 0 then
        x = x + response.normal.x * response.depth
        y = y + response.normal.y * response.depth
    end

    return x, y, world:project(response.item, x, y, filter, query)
end

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param filter slick.worldFilterQueryFunc
--- @return number, number, slick.worldQueryResponse[], number, slick.worldQuery
local function touch(world, query, response, x, y, filter)
    if response.time > 0 and response.time < 1 then
        x = response.entity.transform.x + response.offset.x
        y = response.entity.transform.y + response.offset.y
    elseif response.depth > 0 then
        x = response.entity.transform.x + response.normal.x * response.depth
        y = response.entity.transform.y + response.normal.y * response.depth
    end

    query:reset()

    return x, y, query.results, 0, query
end

--- @param world slick.world
--- @param query slick.worldQuery
--- @param response slick.worldQueryResponse
--- @param x number
--- @param y number
--- @param filter slick.worldFilterQueryFunc
--- @return number, number, slick.worldQueryResponse[], number, slick.worldQuery
local function cross(world, query, response, x, y, filter)
    return x, y, world:project(response.item, x, y, filter, query)
end

return {
    slide = slide,
    touch = touch,
    cross = cross
}
