local slick = require "slick"
local common = {}

function common.makeGearShape(innerRadius, outerRadius, innerTaper, outerTaper, notches)
    -- Borrowed from here: https://stackoverflow.com/a/23532468

    innerRadius = innerRadius or 128
    outerRadius = outerRadius or 96
    innerTaper = innerTaper or 0.5
    outerTaper = outerTaper or 0.3
    notches = notches or 5

    local angle = math.pi * 2 / (notches * 2)
    local innerT = angle * (innerTaper / 2)
    local outerT = angle * (outerTaper / 2)
    local toggle = false

    local points = {}
    for a = angle, math.pi * 2, angle do
        if toggle then
            table.insert(points, innerRadius * math.cos(a - innerT))
            table.insert(points, innerRadius * math.sin(a - innerT))

            table.insert(points, outerRadius * math.cos(a + outerT))
            table.insert(points, outerRadius * math.sin(a + outerT))
        else
            table.insert(points, outerRadius * math.cos(a - outerT))
            table.insert(points, outerRadius * math.sin(a - outerT))

            table.insert(points, innerRadius * math.cos(a + innerT))
            table.insert(points, innerRadius * math.sin(a + innerT))
        end

        toggle = not toggle
    end

    return slick.newPolygonMeshShape(points)
end

--- @param world slick.world
--- @param x number
--- @param y number
function common.makeGear(world, x, y, shape)
    local gear = {
        angle = love.math.random() * math.pi * 2,
        angularVelocity = (love.math.random() * 0.5 + 0.5) * math.pi / 4,
        x = x,
        y = y
    }

    world:add(gear, x, y, shape)

    return gear
end

local function thingPushFilter(item)
    return item.type == "player"
end

local function notLevelRotateFilter(item)
    return not (item.type == "level" or item.type == "gear")
end

--- @param gear any
--- @param world slick.world
--- @param deltaTime number
function common.updateGear(gear, world, deltaTime)
    gear.angle = gear.angle + gear.angularVelocity * deltaTime
    world:rotate(gear, gear.angle, notLevelRotateFilter, thingPushFilter)
end

local generate_constant = function() return 1 end

-- borrowed from https://github.com/1bardesign/batteries/blob/master/pathfind.lua
function common.pathfind(args)
	local start = args.start or args.start_node
	local is_goal = args.is_goal or args.goal
	local neighbours = args.neighbours or args.generate_neighbours
	local distance = args.distance or args.weight or args.g or generate_constant
	local heuristic = args.heuristic or args.h or generate_constant

	local predecessor = {}
	local seen = {}
	local f_score = {[start] = 0}
	local g_score = {[start] = 0}

	local function search_compare(a, b)
		return
			(f_score[a] or math.huge) >
			(f_score[b] or math.huge)
	end
	local to_search = {}

	local current = start
	while current and not is_goal(current) do
		seen[current] = true
		for i, node in ipairs(neighbours(current)) do
			if not seen[node] then
				local tentative_g_score = (g_score[current] or math.huge) + distance(current, node)
				if g_score[node] == nil then
					if tentative_g_score < (g_score[node] or math.huge) then
						predecessor[node] = current
						g_score[node] = tentative_g_score
						f_score[node] = tentative_g_score + heuristic(node)
					end
					table.insert(to_search, node)
                    table.sort(to_search, search_compare)
				end
			end
		end
		current = table.remove(to_search)
	end

	--didn't make it to the goal
	if not current or not is_goal(current) then
		return false
	end

	--build up result path
	local result = {}
	while current do
		table.insert(result, 1, current)
		current = predecessor[current]
	end
	return result
end

return common
