function love.conf(t)
    print("love.conf")
    t.modules.graphics = false
end

function love.load()
    require("test.main")
end
