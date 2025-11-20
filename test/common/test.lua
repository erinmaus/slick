local testRunner = require("test.common.testRunner")

--- @alias slick.test.updateFunc fun(dt: number): slick.worldResponseFunc[]
--- @alias slick.test.runFunc fun()
--- @alias slick.test.testFunc fun(t: slick.test)

--- @class slick.test
--- @field timeout number
--- @field name string
--- @field private _updateFunc slick.test.updateFunc
local test = {}
local metatable = { __index = test }

function test.new(name)
    return setmetatable({
        name = name,
        timeout = 10
    }, metatable)
end

--- @param func slick.test.updateFunc
function test:moveForOneFrame(func)
    --- @type number
    local dt = coroutine.yield({ test = self, reason = "step" })
    return func(dt)
end

--- @param func slick.test.updateFunc
--- @param count number?
--- @return slick.worldQueryResponse[]
function test:moveUntilCollision(func, count)
    local time = 0

    local c
    repeat
        --- @type number
        local dt = coroutine.yield({ test = self, reason = "step" })
        time = time + dt

        assert(time < self.timeout, "test timeout")

        c = func(dt)
    until (count and #c == count) or (not count and #c >= 1)

    return c
end

--- @param func slick.test.updateFunc
function test:moveUntilNoCollision(func)
    local time = 0

    local c, dt
    repeat
        --- @type number
        dt = coroutine.yield({ test = self, reason = "step" })
        time = time + dt

        assert(time < self.timeout, "test timeout")
        c = func(dt)
    until (#c == 0 and dt > 0)
end

--- comment
--- @param name string
--- @param func slick.test.testFunc
local t = function(name, func)
    local result = test.new(name)
    testRunner:add(result, func)
end

return t
