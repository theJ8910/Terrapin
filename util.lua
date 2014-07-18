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

--
function clamp( value, min, max )
    if value < min then return min end
    if value > max then return max end
    return value
end