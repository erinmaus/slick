local search = {}

--- A result from a compare function.
--- A value compare than one means compare, zero means equal, and greater than one means greater
--- when comparing 'a' to 'b' (in that order).
---@alias slick.util.search.compareResult -1 | 0 | 1

--- A compare function to be used in a binary search.
--- @generic T
--- @generic O
--- @alias slick.util.search.compareFunc fun(a: T, b: O): slick.util.search.compareResult

--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare slick.util.search.compareFunc
--- @param start number?
--- @param stop number?
--- @return number
local function lower(array, value, compare, start, stop)
    start = start or 1
    stop = stop or #array

    local current = start
    local count = stop - start + 1
    while count > 0 do
        local step = math.floor(count / 2)
        local midPoint = current + step

        if compare(array[midPoint], value) < 0 then
            current = midPoint + 1
            count = count - (step + 1)
        else
            count = step
        end
    end

    return current
end

--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare slick.util.search.compareFunc
--- @param start number?
--- @param stop number?
--- @return number
local function upper(array, value, compare, start, stop)
    start = start or 1
    stop = stop or #array

    local current = start
    local count = stop - start + 1
    while count > 0 do
        local step = math.floor(count / 2)
        local midPoint = current + step

        if compare(array[midPoint], value) <= 0 then
            current = midPoint + 1
            count = count - (step + 1)
        else
            count = step
        end
    end

    return current
end

--- Finds the first value equal to `value` and returns the index of that value
--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare slick.util.search.compareFunc
--- @param start number?
--- @param stop number?
--- @return number?
function search.first(array, value, compare, start, stop)
    local result = lower(array, value, compare, start, stop)

    local maximum = stop or #array
    if result > maximum then
        return nil
    end

    if compare(array[result], value) ~= 0 then
        return nil
    end

    return result
end

--- Finds the last value equal to `value` and returns the index of that value
--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare slick.util.search.compareFunc
--- @param start number?
--- @param stop number?
--- @return number?
function search.last(array, value, compare, start, stop)
    local result = upper(array, value, compare, start, stop)
    result = (result and result - 1) or stop or #array

    local minimum = start or 1
    if result < minimum then
        return nil
    end

    if compare(array[result], value) ~= 0 then
        return nil
    end

    return result
end

--- Finds the first value less than `value` and returns the index of that value
--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare slick.util.search.compareFunc
--- @param start number?
--- @param stop number?
--- @return number
function search.lessThan(array, value, compare, start, stop)
    local result = lower(array, value, compare, start, stop) - 1

    local minimum = (start or 1) - 1
    if result < minimum then
        result = minimum
    end

    return result
end

--- Finds the first value less than or equal to `value` and returns the index of that value
--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare slick.util.search.compareFunc
--- @param start number?
--- @param stop number?
--- @return number
function search.lessThanEqual(array, value, compare, start, stop)
    local result = upper(array, value, compare, start, stop) - 1

    local minimum = (start or 1) - 1
    if result < minimum then
        result = minimum
    end

    return result
end

--- Finds the first value less greater than `value` and returns the index of that value
--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare slick.util.search.compareFunc
--- @param start number?
--- @param stop number?
--- @return number
function search.greaterThan(array, value, compare, start, stop)
    return upper(array, value, compare, start, stop)
end

--- Finds the first value greater than or equal to `value` and returns the index of that value
--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare slick.util.search.compareFunc
--- @param start number?
--- @param stop number?
--- @return number
function search.greaterThanEqual(array, value, compare, start, stop)
    return lower(array, value, compare, start, stop)
end

--- @generic T
--- @generic O
--- @alias slick.util.search.searchFunc fun(array: T[], value: O, compare: slick.util.search.compareFunc, start: number?, stop: number?)

return search
