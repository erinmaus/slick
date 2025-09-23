--- @alias slick.test.testRunnerTest { t: slick.test, fun: slick.test.runFunc }

--- @class slick.test.testRunner
--- @field tests slick.test.testRunnerTest[]
local testRunner = {}
testRunner.tests = {}

--- @param t slick.test
--- @param fun slick.test.testFunc
function testRunner:add(t, fun)
    table.insert(self.tests, {
        t = t,
        fun = fun
    })
end

return testRunner
