local slicktable = {}

--- @type fun(t: table)
local clear
do
    local s, r = pcall(require, "table.clear")
    if s then
        clear = r
    else
        function clear(t)
            while #t > 0 do
                table.remove(t, #t)
            end

            for k in pairs(t) do
                t[k] = nil
            end
        end
    end
end

slicktable.clear = clear

return slicktable
