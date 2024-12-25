local IS_DEBUG = os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1"
if IS_DEBUG then
    jit.off()

    require("lldebugger").start()

    function love.errorhandler(msg)
        error(msg, 2)
    end
end

function love.conf(t)
    t.console = true
    t.window.width = 1600
    t.window.height = 900
end
