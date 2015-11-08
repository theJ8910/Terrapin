--An insets object represents spacing on the outside / inside of a rectangle (i.e. padding / margins).
--Stores l, t, r, and b values internally (left, top, right, and bottom respectively).
--An insets is considered valid if l, t, r, and b are all non-negative.
require( "serialize" )
require( "ids" )

--rect
local c = {}

--Initializes a rect with the given l, t, r, b values (expected)
function c:init( l, t, r, b )
    self.l = l
    self.t = t
    self.r = r
    self.b = b
end

--Returns a copy of this insets
function c:copy()
    return new.insets(
        self.l,
        self.t,
        self.r,
        self.b
    )
end

--Allows you to do insets1 == insets2 and insets1 ~= insets2
function c:__eq( other )
    return self.l == other.l and
           self.t == other.t and
           self.r == other.r and
           self.b == other.b
end

--Sets the left, top, right, and bottom of the insets
function c:set( l, t, r, b )
    self.l = l
    self.t = t
    self.r = r
    self.b = b
end

--Returns the left, top, right, and bottom of the insets
function c:get()
    return self.l, self.t, self.r, self.b
end

--Returns true if l == t == r == b == 0.
--Returns false otherwise.
function c:isZero()
    return self.l == 0 and
           self.t == 0 and
           self.r == 0 and
           self.b == 0
end

--Returns true if l, t, r, and b are all non-negative.
--Returns false otherwise.
function c:isValid()
    return self.l >= 0 and
           self.t >= 0 and
           self.r >= 0 and
           self.b >= 0
end

function c:getSerialID()
    return ids.INSETS
end

function c:save( writer )
    writer:writeNumber( self.l )
    writer:writeNumber( self.t )
    writer:writeNumber( self.r )
    writer:writeNumber( self.b )
end

function c:load( reader )
    self.l = reader:readNumber()
    self.t = reader:readNumber()
    self.r = reader:readNumber()
    self.b = reader:readNumber()
end

--String description of insets
function c:__tostring()
    return string.format( "[%d,%d,%d,%d]", self.l, self.t, self.r, self.b )
end

class.register( "insets", c )

serialize.register( function( serialID ) return new.insets( 0, 0, 0, 0 ) end, ids.INSETS )