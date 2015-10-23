--Prints a human readable version of the given table, showing 10 rows at a time.
function printTable( tbl )
    local keyWidth   = 5
    local valueWidth = 5
    for k,v in pairs( tbl ) do
        keyWidth = math.max( keyWidth, #tostring( k ) )
        valueWidth = math.max( valueWidth, #tostring( v ) )
    end
    
    local count = 0
    for k,v in pairs( tbl ) do
        io.write( column( tostring( k ), keyWidth ) )
        io.write( " | " )
        io.write( column( type( v ), 8 ) )
        io.write( " | " )
        if type( v ) ~= "table" then
            io.write( column( tostring( v ), valueWidth ) )
        else
            io.write( "[table]" )
        end
        io.write( "\n" )
        count = count + 1
        if count == 10 then io.read(); count = 0 end
    end
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