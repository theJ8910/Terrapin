require( "serialize" )
require( "ids" )

--point
local c = {}

function c:init( x, y )
    self.x = x
    self.y = y
end

function c:set( x, y )
    self.x = x
    self.y = y
end

function c:get()
    return self.x, self.y
end

function c:copy()
    return new.point( self.x, self.y )
end

--Check if two points are equal
function c:__eq( other )
    return self.x == other.x and
           self.y == other.y
end

--String description of point
function c:__tostring()
    return string.format( "(%d,%d)", self.x, self.y )
end

function c:getSerialID()
    return ids.POINT
end

function c:save( writer )
    writer:writeNumber( self.x )
    writer:writeNumber( self.y )
end

function c:load( reader )
    self.x = reader:readNumber()
    self.y = reader:readNumber()
end

class.register( "point", c )

serialize.register( function( serialID ) return new.point( 0, 0 ) end, ids.POINT )