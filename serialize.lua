require( "class" )

--Type IDs
local NIL     = 0
local BOOLEAN = 1
local SI8     = 2
local UI8     = 3
local SI16    = 4
local UI16    = 5
local SI32    = 6
local UI32    = 7
local NUMBER  = 8
local STRING  = 9
local TABLE   = 10
local OBJECT  = 11

--Lame! Computercraft's "write" method uses signed bytes, and doesn't even wrap them properly!
--(e.g. it does 126, 127, 0, 1, 2... instead of 126, 127, -128, -127...)
--Since they're using signed bytes, for values over 127, I need to produce a negative
--integer whose binary would, if interpreted as an unsigned number, would equal that value.
--Luckily this can be done pretty simply by subtracting 256 from the value.
--Negative numbers use two's-compliment, so 0 would be 00000000,
-- -1 would be 11111111, -2 would be 11111110, etc. Do the math and you'll see why subtracting 256 works.
--This function expects the given value to be between 0 and 255.
local function byte( value )
    if value > 127 then
        return value - 256
    end
    return value
end

--Reads a byte from the given file.
--If the byte is nil, an "end of stream reached" error is thrown.
local function readByte( file )
    local byte = file:read()
    if byte == nil then
        error( "End of stream reached" )
    end
    return byte
end

--We can reduce the amount of space an arbitrary written number takes up in the written file
--based on whether or not it is integral, and what range it falls in.
local function writeNumber( writer, value )
    --generic number (8 bytes)
    if math.floor( value ) ~= value or value < -2147483648 or value > 4294967296 then
        writer:writeUnsignedInt8( NUMBER )
        writer:writeNumber( value )
    --signed int32 (4 bytes)
    elseif value < -32768 then
        writer:writeUnsignedInt8( SI32 )
        writer:writeSignedInt32( value )
    --signed int16 (2 bytes)
    elseif value < -128 then
        writer:writeUnsignedInt8( SI16 )
        writer:writeSignedInt16( value )
    --signed int8 (1 byte)
    elseif value < 0 then
        writer:writeUnsignedInt8( SI8 )
        writer:writeSignedInt8( value )
    --unsigned int32 (4 bytes)
    elseif value > 65535 then
        writer:writeUnsignedInt8( UI32 )
        writer:writeUnsignedInt32( value )
    --unsigned int16 (2 bytes)
    elseif value > 255 then
        writer:writeUnsignedInt8( UI16 )
        writer:writeUnsignedInt16( value )
    --unsigned int8 (1 byte)
    else
        writer:writeUnsignedInt8( UI8 )
        writer:writeUnsignedInt8( value )
    end
end

--A table can be either a normal table or a serializable object.
--If the given table has a "getSerialID" function, we assume that
--the object is a serializable object and write an object.
--Otherwise, we write a table.
local function writeTable( writer, value )
    if type( value.getSerialID ) == "function" then
        writer:writeUnsignedInt8( OBJECT )
        writer:writeAnyObject( value )
    else
        writer:writeUnsignedInt8( TABLE   )
        writer:writeTable( value )
    end
end

local function writeObjectBase( writer, value )
    local id = writer.objectIDs[ value ]
    if id ~= nil then
        writer:writeUnsignedInt32( id )
        return
    end
    writer.objectCounter = writer.objectCounter + 1
    id = writer.objectCounter
    writer.objectIDs[ value ] = id
end

--Maps a string returned by the type() function to a function that can write it
local typeToWriteFnMap = {
    [ "nil"     ] = function( writer, value ) writer:writeUnsignedInt8( NIL     )                              end,
    [ "boolean" ] = function( writer, value ) writer:writeUnsignedInt8( BOOLEAN ); writer:writeBool( value )   end,
    [ "number"  ] = writeNumber,
    [ "string"  ] = function( writer, value ) writer:writeUnsignedInt8( STRING  ); writer:writeString( value ) end,
    [ "table"   ] = writeTable
}

--Maps a type ID to a function that can read it
local typeToReadFnMap = {
    [ NIL     ] = function( reader ) return nil                        end,
    [ BOOLEAN ] = function( reader ) return reader:readBool()          end,
    [ SI8     ] = function( reader ) return reader:readSignedInt8()    end,
    [ UI8     ] = function( reader ) return reader:readUnsignedInt8()  end,
    [ SI16    ] = function( reader ) return reader:readSignedInt16()   end,
    [ UI16    ] = function( reader ) return reader:readUnsignedInt16() end,
    [ SI32    ] = function( reader ) return reader:readSignedInt32()   end,
    [ UI32    ] = function( reader ) return reader:readUnsignedInt32() end,
    [ NUMBER  ] = function( reader ) return reader:readNumber()        end,
    [ STRING  ] = function( reader ) return reader:readString()        end,
    [ TABLE   ] = function( reader ) return reader:readTable()         end,
    [ OBJECT  ] = function( reader ) return reader:readAnyObject()     end
}

local factories = {}
local function newSerializedObject( serialID )
    local factory = factories[ serialID ]
    if factory == nil then error( string.format( "No factory for serial object with ID \"%s\".", serialID ) ) end
    return factory( serialID )
end

--Registers a factory for a serializeable object.
--When loading an object with the given serialID,
--the given function, factory, is called, passing the serialID as an argument.
--factory is expected to return a new serializeable object with that ID.
--After the object is returned, the :load() method is invoked on it, passing the reader so that the object can load settings from it.
function register( factory, serialID )
    factories[ serialID ] = factory
end

local c = {}

--Returns a new fileReader that reads the path at "path".
function c:init( path )
    local file = io.open( path, "rb" )
    if file == nil then
        error( string.format( "Cannot open \"%s\" for reading.", path ) )
    end
    
    self.file = file
    self.tablesByID = {}
    self.objectsByID = {}
end

--Closes the fileReader. This should be done after you're finished reading the file.
function c:close()
    self.file:close()
end

--Read a variable type of data (could be nil, a number, a bool, table, object, etc)
function c:read()
    local readFn = typeToReadFnMap[ self:readUnsignedInt8() ]
    if readFn == nil then error( "Cannot read the given value. Invalid type: \""..id.."\"" ) end
    return readFn( self )
end

function c:readBool()
    local byte = readByte( self.file )
    if byte == 0 then
        return false
    elseif byte == 1 then
        return true
    else
        error( "Read byte has invalid value; cannot convert to true or false." )
    end
end

function c:readSignedInt8()
    local byte = readByte( self.file )
    if byte > 127 then
        return byte - 256
    end
    return byte
end

function c:readUnsignedInt8()
    return readByte( self.file )
end

function c:readSignedInt16()
    local value = readByte( self.file ) * 256 + readByte( self.file )
    if value > 32767 then
        value = value - 65536
    end
    return value
end

function c:readUnsignedInt16()
    return readByte( self.file ) * 256 + readByte( self.file )
end

function c:readSignedInt32( value )
    local value = readByte( self.file ) * 16777216 + readByte( self.file ) * 65536 + readByte( self.file ) * 256 + readByte( self.file )
    if value > 2147483647 then
        value = value - 4294967296
    end
    return value
end

function c:readUnsignedInt32( value )
    return readByte( self.file ) * 16777216 + readByte( self.file ) * 65536 + readByte( self.file ) * 256 + readByte( self.file )
end

function c:readNumber()
    local byte1 = readByte( self.file )
    local sign
    if byte1 >= 128 then
        sign = -1
    else
        sign = 1
    end
    
    local byte2 = readByte( self.file )
    
    local exponent = ( ( byte1 % 128 ) * 16 + math.floor( byte2 / 16 ) )
    if exponent == 0 then
        for i = 1,6 do readByte( self.file ) end
        return 0
    elseif exponent == 2047 then
        for i = 1,6 do readByte( self.file ) end
        return sign * math.huge
    else
        --Unbias the exponent and calculate the value of 2^exponent
        exponent = exponent - 1023
        local exponentValue = 1
        
        while exponent > 0 do
            exponentValue = exponentValue * 2
            exponent      = exponent - 1
        end
        while exponent < 0 do
            exponentValue = exponentValue / 2
            exponent      = exponent + 1
        end
        
        --Calculate the significand.
        --The significand is a fractional number, but bytes are whole numbers.
        --Furthermore, the significand is spread out across 7 bytes.
        --This means after read a byte containing a part of the significand,
        --we need to move the radix point the appropriate number of places to the left to get the fraction
        --for that piece of the significand. We can think of the significand of being the sum of these fractions.
        --The first four bits of the significand come from the lower 4 bits of the second byte.
        --The division by 16 moves the radix 4 places to the left.
        --The rest of the significand is spread across the remaining 6 bytes, each of which is 8 bits.
        local factor = 16
        local significand = ( byte2 % 16 ) / 16
        for i = 1, 6 do
            --The next 8 bits of the significand will come from the current byte,
            --so we'll need to move the radix an additional 8 places to the left.
            --With the first byte, we read the first 4 bits of the sigificand, so we shifted the radix
            --4 places to the left.
            --For the second byte, we need to shift 4+8 = 12 places to the left (note 2^8 = 256)
            --The third byte would need to be shifted 4+8+8 = 20 places to the left, and so on.
            factor = factor * 256
            significand = significand + readByte( self.file ) / factor
        end
        
        return sign * exponentValue * ( 1 + significand )
    end
end

function c:readString()
    local str = ""
    local bytes = {}
    local length = self:readUnsignedInt32()
    for i = 1, length, 4096 do
        for y = i, math.min( length, i + 4095 ) do
            table.insert( bytes, string.char( readByte( self.file ) ) )
        end
        str = str..table.concat( bytes )
        bytes = {}
    end
    return str
end

function c:readTable()
    --Get the instance ID of the table before we read it.
    --If we've already read a table with this ID, we simply return a reference
    --to the existing table. Doing this not only saves space, but also correctly
    --restores references to shared tables.
    local id = self:readUnsignedInt32()
    local t = self.tablesByID[id]
    if t ~= nil then
        return t
    end
    
    --If we haven't read this table yet, we need to make a new one.
    --The new table is cached so that it isn't created a second time.
    t = {}
    self.tablesByID[ id ] = t
    
    --Read the count so we know how many rows are in the table
    local count = self:readUnsignedInt32()
    
    --Read the key and value of the table
    for i = 1, count do
        t[self:read()] = self:read()
    end
    return t
end

--Reads an object whose type is known ahead of time.
--The serial ID of the object needs to be supplied via the serialID parameter,
--so that the reader knows what kind of object to instantiate.
function c:readObject( serialID )
    local id  = self:readUnsignedInt32()
    local obj = self.objectsByID[id]
    if obj ~= nil then
        return obj
    end
    
    obj = newSerializedObject( serialID )
    self.objectsByID[ id ] = obj
    obj:load( self )
    
    return obj
end

--Reads an object whose type is not known ahead of time.
--The serialID of the object is supplied from the reader
--prior to creating and reading the data for the object.
function c:readAnyObject()
    local id  = self:readUnsignedInt32()
    local obj = self.objectsByID[id]
    if obj ~= nil then
        return obj
    end
    
    obj = newSerializedObject( self:readUnsignedInt16() )
    self.objectsByID[ id ] = obj
    obj:load( self )
    
    return obj
end

class.register( "fileReader", c )




local c = {}
function c:init( path )    
    local file = io.open( path, "wb" )
    if file == nil then
        error( string.format( "Cannot open \"%s\" for writing.", path ) )
    end
    
    self.file = file
    self.tableIDs = {}
    self.tableCounter = 0
    self.objectIDs = {}
    self.objectCounter = 0
    return t
end

function c:close()
    self.file:close()
end

--Write a variable type of data (could be nil, a number, a bool, table, object, etc)
function c:write( value )
    local writeFn = typeToWriteFnMap[ type( value ) ]
    if writeFn == nil then error( "Cannot write the given value. Invalid type: \""..type( value ).."\"" ) end
    writeFn( self, value )
end

function c:writeBool( value )
    if value == true then
        self.file:write( 1 )
    else
        self.file:write( 0 )
    end
end

function c:writeSignedInt8( value )
    value = util.truncate( value )
    if value < -128 or value > 127 then
        error( value.." is outside of signed int8 range [-128, 127]" )
    end
    self.file:write( value )
end

function c:writeUnsignedInt8( value )
    value = util.truncate( value )
    if value < 0 or value > 255 then
        error( value.." is outside of unsigned int8 range [0, 255]" )
    end
    self.file:write( byte( value ) )
end

function c:writeSignedInt16( value )
    value = util.truncate( value )
    if value < -32768 or value > 32767 then
        error( value.." is outside of signed int16 range [-32768, 32767]" )
    end
    if value < 0 then
        value = 65536 + value
    end
    self.file:write( byte( math.floor( value / 256  ) ) )
    self.file:write( byte( value % 256 ) )
end

function c:writeUnsignedInt16( value )
    value = util.truncate( value )
    if value < 0 or value > 65535 then
        error( value.." is outside of unsigned int16 range [0, 65535]" )
    end
    self.file:write( byte( math.floor( value / 256  ) ) )
    self.file:write( byte( value % 256 ) )
end

function c:writeSignedInt32( value )
    value = util.truncate( value )
    if value < -2147483648 or value > 2147483647 then
        error( value.." is outside of signed int32 range [-2147483648, 2147483647]" )
    end
    if value < 0 then
        value = 4294967296 + value
    end
    --Left-shift 3 bytes
    self.file:write( byte( math.floor(   value              / 16777216 ) ) )
    --Truncate byte 4, right shift 2 bytes
    self.file:write( byte( math.floor( ( value % 16777216 ) / 65536    ) ) )
    --Truncate byte 4 and 3, right shift 1 byte
    self.file:write( byte( math.floor( ( value % 65536    ) / 256      ) ) )
    --Truncate byte 4, 3, and 2.
    self.file:write( byte(               value % 256                     ) )
end

function c:writeUnsignedInt32( value )
    value = util.truncate( value )
    if value < 0 or value > 4294967295 then
        error( value.." is outside of unsigned int32 range [0, 4294967295]" )
    end
    
    --Left-shift 3 bytes
    self.file:write( byte( math.floor(   value              / 16777216 ) ) )
    --Truncate byte 4, right shift 2 bytes
    self.file:write( byte( math.floor( ( value % 16777216 ) / 65536    ) ) )
    --Truncate byte 4 and 3, right shift 1 byte
    self.file:write( byte( math.floor( ( value % 65536    ) / 256      ) ) )
    --Truncate byte 4, 3, and 2.
    self.file:write( byte(               value % 256                     ) )
end

function c:writeNumber( value )
    --Any number (besides 0 and infinity) can be broken into three parts according to the following formula:
    --  sign * 2^(exponent) + fractional part
    --where sign is either -1 or 1, and "fractional part" is non-negative.
    --The IEEE764 double encoding specifies a way to encode these three parts as binary, using a
    --total of 8 bytes (64 bits). The encoding allows numbers that (potentially) have fractional parts
    --to be represented in computer memory. This is the encoding that Lua uses for its numbers.
    --The encoding is divided into three sections, from highest to lowest position:
    --sign (1 bit), biased exponent (11 bits), and significand (52 bits - also called a mantissa).
    --Each written byte consists of, in order:
    --    sign bit + upper 7 bits from exponent
    --    lower 4 bits from exponent + upper 4 bits from signficand
    --    next 8 bits from the significand
    --    next 8 bits from the significand
    --    next 8 bits from the significand
    --    next 8 bits from the significand
    --    next 8 bits from the significand
    --    lowest 8 bits from the significand
    
    --Determine the sign of the number.
    --Negative numbers use a sign bit with a value of "1".
    --All other numbers have a sign bit of "0".
    local sign
    if value < 0 then
        value = -value
        sign = 128
    else
        sign = 0
    end
    
    --Zero (and subnormals) are represented with a biased exponent of 0
    --Our code ignores subnormals
    if value == 0 then
        self.file:write( byte( sign ) )
        self.file:write( byte( 0 ) )
        self.file:write( byte( 0 ) )
        self.file:write( byte( 0 ) )
        self.file:write( byte( 0 ) )
        self.file:write( byte( 0 ) )
        self.file:write( byte( 0 ) )
        self.file:write( byte( 0 ) )
        
    --Infinity (and NaNs) are represented with a biased exponent of 2047
    --Our code ignores NaNs
    elseif value == math.huge then        
        self.file:write( byte( sign + 127 ) )
        self.file:write( byte( 240 ) )
        self.file:write( byte( 0 ) )
        self.file:write( byte( 0 ) )
        self.file:write( byte( 0 ) )
        self.file:write( byte( 0 ) )
        self.file:write( byte( 0 ) )
        self.file:write( byte( 0 ) )
        
    --For any other number we need to calculate the biased exponent
    else
        --"Biased" refers to the practice of shifting the actual exponent by 1023.
        --Therefore an exponent of 0 would have a biased exponent of 1023,
        --positive exponents would be above this, and negative exponents below this.
        local exponent = 1023
        while value >= 2 do
            value    = value    / 2
            exponent = exponent + 1
        end
        while value < 1 do
            value    = value    * 2
            exponent = exponent - 1
        end
        self.file:write( byte( sign + math.floor( exponent / 16 ) ) )
        
    
        --For each bit in the signficand, write a "1" or "0"
        --Note: We subtract "1" here because after calculating the exponent above,
        --the value is normalized as "1.xxx". The significand (the part we're interested in) is
        --the fractional part of that number.
        --We multiply the value by 16 to move the upper 4 bits of the significand to the left of the radix.
        value = ( value - 1 ) * 16
        self.file:write( byte( ( exponent % 16 ) * 16 + math.floor( value ) ) )
        
        for i = 1, 6 do
            value = ( value % 256 ) * 256
            self.file:write( byte( math.floor( value ) ) )
        end
    end
end

function c:writeString( value )
    --Write the length of the string so we know how many characters to read ahead of time
    --Another advantage of using the length (rather than some other method like null-terminating the string)
    --is that it allows for strings containing null characters
    local length = #value
    self:writeUnsignedInt32( length )
    
    --Write each byte in the string
    for i = 1, length do
        self.file:write( byte( string.byte( value, i ) ) )
    end
end

function c:writeTable( value, ignoreNonSerialData )
    --If the table has been written before, we can write just the instance ID
    --and nothing more, since the contents have already been recorded.
    local id = self.tableIDs[ value ]
    if id ~= nil then
        self:writeUnsignedInt32( id )
        return
    end
    
    --Otherwise, increment the counter to get an instance ID for the table and cache it
    self.tableCounter = self.tableCounter + 1
    id = self.tableCounter
    self.tableIDs[ value ] = id
    
    --Write the table's instance ID
    self:writeUnsignedInt32( id )
    
    --Write a count the number of entries in the table
    local size = 0
    for k, v in pairs( value ) do
        size = size + 1
    end
    self:writeUnsignedInt32( size )
    
    --For each key and value in the table, write an identifying byte followed by the key/value's serialized form.
    for k, v in pairs( value ) do
        self:write( k )
        self:write( v )
    end

end

--Writes an object without including the serial ID of the object
--Code that loads the object is expected to know what type of object it is ahead of time.
function c:writeObject( value )
    writeObjectBase( self, value )
    
    self:writeUnsignedInt32( id )
    value:save( self )
end

--Writes an object, including the serial ID of the object.
--Code that loads the object does not need to know the type of the object ahead of time.
function c:writeAnyObject( value )
    writeObjectBase( self, value )
    
    self:writeUnsignedInt32( id )    
    self:writeUnsignedInt16( value:getSerialID() )
    value:save( self )
end

class.register( "fileWriter", c )