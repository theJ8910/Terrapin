--Prints a human readable version of the given table, showing 10 rows at a time.
--It does not print subtables (i.e. it is not recursive).
--writeFn is an optional function that will be used to print the table.
--    This should be a function that takes the text to print as its sole argument.
--    This function should NOT append a newline to the output (i.e. you should use something like io.write instead of print).
--    writeFn defaults to io.write.
function printTable( tbl, writeFn )
    if writeFn == nil then writeFn = io.write end

    local keyWidth   = 5
    local valueWidth = 5
    for k,v in pairs( tbl ) do
        keyWidth = math.max( keyWidth, #tostring( k ) )
        valueWidth = math.max( valueWidth, #tostring( v ) )
    end
    
    local count = 0
    for k,v in pairs( tbl ) do
        writeFn( column( tostring( k ), keyWidth ) )
        writeFn( " | " )
        writeFn( column( type( v ), 8 ) )
        writeFn( " | " )
        if type( v ) ~= "table" then
            writeFn( column( tostring( v ), valueWidth ) )
        else
            writeFn( "[table]" )
        end
        writeFn( "\n" )
        count = count + 1
        if count == 10 then io.read(); count = 0 end
    end
end

--Recursive step of copyTable.
--See copyTable for more information.
local function copyTableRecursive( tbl, references )
    local copy = {}
    references[ tbl ] = copy

    for k,v in pairs( tbl ) do
        --Recursively copy table
        if type( v ) == "table" then
            --Have we copied the same table once before?
            --If so, this is a shared table. Return the copy we've made before. Not only does this save work,
            --but it ensures that tables that were shared in the original will be shared in the copy.
            local reference = references[ v ]
            if ref ~= nil then copy[ k ] = reference
            else               copy[ k ] = copyTableRecursive( v, references )
            end
        --Copy a normal key
        else
            copy[ k ] = v
        end
    end

    return copy
end

--Returns a copy of the given table.
--Subtables are copied recursively. Any shared tables will be copied and shared as well.
--Currently, metatables are not copied.
--e.g. this is guaranteed:
--    local shared = {}
--    local tbl = {
--        a = shared,
--        b = shared
--    }
--    print( tbl.a  == tbl.b  ) --prints true
--
--    local copy = util.copyTable( tbl )
--    print( copy.a == copy.b ) --prints true
function copyTable( tbl )
    local references = {}
    return copyTableRecursive( tbl, references )
end

--Returns a string that is colWidth characters wide.
--If str is less than colWidth characters, the end of the string is padded with the enough fill characters (which defaults to " ") to make it long enough.
--If str is greater than colWidth characters, characters are trimmed from the end of the string to make it long enough.
function column( str, colWidth, fill )
    if fill == nil then fill = " " end
    
    local len = #str
    if len > colWidth then
        str = string.substring( str, 1, colWidth )
    elseif len < colWidth then
        str = str..string.rep( fill, colWidth - len )
    end
    
    return str
end

--Removes the decimal point from the given value and returns it
function truncate( value )
    if value > 0 then
        return math.floor( value )
    else
        return math.ceil( value )
    end
end

--Limits the given value to the range [min,max] and returns it.
function clamp( value, min, max )
    if value < min then return min end
    if value > max then return max end
    return value
end

--Rounds the given value to the nearest whole.
--.5 is rounded up to 1.0, and -.5 is rounded down to -1.0.
function round( value )
    --NOTE:
    --math.floor( -1.5 ) = -2
    --math.ciel( -1.5 )  = -1
    if value > 0 then return math.floor( value + 0.5 )
    else              return math.ceil(  value - 0.5 )
    end
end

--Creates a string from the values in the given array, t.
--Values appear in the string by their numerical order, i.e. t[1], t[2], ..., t[n]
--Values are separated by the given separator, which defaults to ","
--If t is empty, an empty string is returned.
function join( t, separator )
    local c = #t
    if c == 0 then return "" end
    
    if separator == nil then separator = "," end

    local str = tostring( t[1] )
    for i = 2, c do
        str = str..separator..tostring( t[i] )
    end
    return str
end

--Test if "fn" causes the program to yield, and if so, for how long.
--Calls fn, providing any addtional arguments (...) given to the function to fn.
--If fn is not a function, or fn encounters an error when called, the error is propagated.
--Returns (true, time) if fn called coroutine.yield(), or (false, time) if it didn't.
function yields( fn, ... )
    local c = coroutine.create( fn )

    local t = os.clock()
    local success, err = coroutine.resume( c, ... )
    t = os.clock() - t

    if not success then return error( err ) end

    return coroutine.status( c ) ~= "dead", t
end