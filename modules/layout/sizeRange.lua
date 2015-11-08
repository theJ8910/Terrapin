--An sizeRange object stores minimum and maximum widths and heights.
--Stores minW, maxW, minH, and maxH values internally.
--A sizeRange is considered valid if maxW >= minW >= 0, maxH >= minH >= 0.
--maxW and maxH are permitted to be math.huge (infinity).
require( "serialize" )
require( "ids" )

--sizeRange
local c = {}

--Initalizes a sizeRange with the given minW, maxW, minH, and maxH values.
function c:init( minW, maxW, minH, maxH )
    self.minW = minW
    self.maxW = maxW
    self.minH = minH
    self.maxH = maxH
end

--Returns a copy of this sizeRange
function c:copy()
    return new.sizeRange(
        self.minW,
        self.maxW,
        self.minH,
        self.maxH
    )
end

--Allows you to do sizeRange1 == sizeRange2 and sizeRange1 ~= sizeRange2
function c:__eq( other )
    return self.minW == other.minW and
           self.maxW == other.maxW and
           self.minH == other.minH and
           self.maxH == other.maxH
end

--Sets the minW, maxW, minH, and maxH of the sizeRange
function c:set( minW, maxW, minH, maxH )
    self.minW = minW
    self.maxW = maxW
    self.minH = minH
    self.maxH = maxH
end

--Returns the minW, maxW, minH, and maxH of the sizeRange
function c:get()
    return self.minW, self.maxW, self.minH, self.maxH
end

--Returns true if the width and height of given size are within the mins and maxs for each (inclusive).
function c:contains( size )
    return size.w >= self.minW and size.w <= self.maxW and
           size.h >= self.minH and size.h <= self.maxH
end

--Returns true if minW, maxW, minH, and maxH are all non-negative.
--Returns false otherwise.
function c:isValid()
    return self.maxW >= self.minW and
           self.minW >= 0 and
           self.maxH >= self.minH and
           self.minH >= 0
end

function c:getSerialID()
    return ids.SIZERANGE
end

function c:save( writer )
    writer:writeNumber( self.minW )
    writer:writeNumber( self.maxW )
    writer:writeNumber( self.minH )
    writer:writeNumber( self.maxH )
end

function c:load( reader )
    self.minW = reader:readNumber()
    self.maxW = reader:readNumber()
    self.minH = reader:readNumber()
    self.maxH = reader:readNumber()
end

--String description of sizeRange
function c:__tostring()
    return string.format( "([%d,%d],[%d,%d])", self.minW, self.maxW, self.minH, self.maxH )
end

class.register( "sizeRange", c )

serialize.register( function( serialID ) return new.sizeRange( 0, 0, 0, 0 ) end, ids.SIZERANGE )