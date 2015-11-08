require( "serialize" )
require( "ids" )

--size
local c = {}

function c:init( w, h )
    self.w = w
    self.h = h
end

function c:set( w, h )
    self.w = w
    self.h = h
end

function c:get()
    return self.w, self.h
end

function c:copy()
    return new.size( self.w, self.h )
end

--Check if two sizes are equal
function c:__eq( other )
    return self.w == other.w and
           self.h == other.h
end

--String description of size
function c:__tostring()
    return string.format( "[%dx%d]", self.x, self.y )
end

function c:getSerialID()
    return ids.SIZE
end

function c:save( writer )
    writer:writeNumber( self.w )
    writer:writeNumber( self.h )
end

function c:load( reader )
    self.w = reader:readNumber()
    self.h = reader:readNumber()
end

class.register( "size", c )

serialize.register( function( serialID ) return new.size( 0, 0 ) end, ids.SIZE )