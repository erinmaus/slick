local testRunner = require("test.common.testRunner")

require("test.bobble")
require("test.clockwise")
require("test.contactPoints")
require("test.sheepo")
require("test.sheepo2")
require("test.slopes")
require("test.transform")

local c = 0
local deltaFuncs = {
    function()
        return 1 / 60
    end,

    function ()
        return 1 / 60 + love.math.random() * 1 / 120
    end,

    function ()
        return (love.math.random() * 0.5 + 0.5) * (1 / 60)
    end,

    function ()
        c = c + 1
        return ({ 0, 1 / 60 })[(c % 2) + 1]
    end,

    function ()
        return 0.25
    end,

    function ()
        return 1 / 100000
    end,

    function()
        return (love.math.random() * 0.5 + 0.5) * (1 / 100000)
    end
}

local deltaFuncNames = {
    "1 / 60",
    "1 / 60 + random() <= 1/120",
    "random(0.5, 1.0) <= 1 / 60",
    "0, then 1/60, then 0, then 1/60... and so on",
    "0.25",
    "1 / 100000",
    "random(0.5, 1.0) <= 1 / 1000",
}

local exitCode = 0
for d, deltaFunc in ipairs(deltaFuncs) do
    for _, t in ipairs(testRunner.tests) do
        local f = coroutine.create(t.fun)
        
        local success = true
        do
            local s, e = coroutine.resume(f, t.t)
            if not s then
                success = false
                print(string.format("[FAILED] '%s' @ delta func '%s': %s (%s)", t.t.name, deltaFuncNames[d] or "???", e, debug.traceback(f)))
            end
        end

        while success and coroutine.status(f) ~= "dead" do
            local s, e = coroutine.resume(f, deltaFunc())
            if not s then
                success = false
                print(string.format("[FAILED] '%s' @ delta func '%s': %s (%s)", t.t.name, deltaFuncNames[d] or "???", e, debug.traceback(f)))
            end
        end

        if success then
            print(string.format("[PASSED] '%s' @ delta func '%s'", t.t.name, deltaFuncNames[d] or "???"))
        else
            exitCode = 1
        end
    end
end

love.event.quit(exitCode)
