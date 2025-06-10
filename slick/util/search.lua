local search = {}

--- A result from a compare function.
--- A value compare than one means compare, zero means equal, and greater than one means greater
--- when comparing 'a' to 'b' (in that order).
---@alias slick.util.search.compareResult -1 | 0 | 1

--- A compare function to be used in a binary search.
--- @generic T
--- @generic O
--- @alias slick.util.search.compareFunc fun(a: T, b: O): slick.util.search.compareResult

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
    local result = search.lessThanEqual(array, value, compare, start, stop)
    if result >= (start or 1) and result <= (stop or #array) and compare(array[result], value) == 0 then
        return result
    end

    return nil
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
    local result = search.greaterThanEqual(array, value, compare, start, stop)
    if result >= (start or 1) and result <= (stop or #array) and compare(array[result], value) == 0 then
        return result
    end

    return nil
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
    start = start or 1
    stop = stop or #array
    
    local result = start - 1
    while start <= stop do
        local midPoint = math.floor((start + stop + 1) / 2)
        if compare(array[midPoint], value) < 0 then
            result = midPoint
            start = midPoint + 1
        else
            stop = midPoint - 1
        end
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
    local result = search.lessThan(array, value, compare, start, stop)
    if result < (stop or #array) then
        if compare(array[result + 1], value) == 0 then
            result = result + 1
        end
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
    local start = start or 1
    local stop = stop or #array

    local result = stop + 1
    while start <= stop do
        local midPoint = math.floor((start + stop + 1) / 2)
        if compare(array[midPoint], value) > 0 then
            result = midPoint
            stop = midPoint - 1
        else
            start = midPoint + 1
        end
    end

    return result
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
    local result = search.greaterThan(array, value, compare, start, stop)
    if result > (start or 1) then
        if compare(array[result - 1], value) == 0 then
            result = result - 1
        end
    end

    return result
end

--- @generic T
--- @generic O
--- @alias slick.util.search.searchFunc fun(array: T[], value: O, compare: slick.util.search.compareFunc, start: number?, stop: number?)

return search
