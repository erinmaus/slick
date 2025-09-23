local IS_DEBUG = os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1"
if IS_DEBUG then
    jit.off()

    require("lldebugger").start()

    function love.errorhandler(msg)
        error(msg, 2)
    end
end

function love.conf(t)
    if os.getenv("CI") then
        print("Running in CI, disabling graphics, window, and audio.")
        t.modules.graphics = false
        t.modules.window = false
        t.modules.audio = false
    end

    t.window.width = 640
    t.window.height = 480
    t.window.title = "slick demo"
end
