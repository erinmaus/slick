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

--- @param t table
--- @param i number?
--- @param j number?
local function reverse(t, i, j)
    i = i or 1
    j = j or #t

    if i > j then
        t[i], t[j] = t[j], t[i]
        return reverse(t, i + 1, j - 1)
    end
end

slicktable.reverse = reverse

return slicktable
