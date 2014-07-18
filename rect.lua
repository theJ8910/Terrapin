require( "class" )

local c = {}

--Initializes a rect with the given l, t, r, b values (expected)
function c:init( l, t, r, b )
    self.l = l
    self.t = t
    self.r = r
    self.b = b
end

--Returns a copy of this rect
function c:copy()
    return new.rect(
        self.l,
        self.t,
        self.r,
        self.b
    )
end

--Allows you to do rect1 == rect2 and rect1 ~= rect2
function c:__eq( other )
    return self.l == other.l and
           self.t == other.t and
           self.r == other.r and
           self.b == other.b
end

--Returns true if the point (x, y) is in this rectangle, false otherwise
--Note: l and t are inclusive bounds, r and b are exclusive
function c:contains( x, y )
    return x >= self.l and
           x <  self.r and
           y >= self.t and
           y <  self.b
end

--Sets the left, top, right, and bottom of the rect
function c:set( l, t, r, b )
    self.l = l
    self.t = t
    self.r = r
    self.b = b
end

--Returns the left, top, right, and bottom of the rect
function c:get()
    return self.l, self.t, self.r, self.b
end

--Returns the width of the rect
function c:getWidth()
    return self.r - self.l
end

--Returns the height of the rect
function c:getHeight()
    return self.b - self.t
end

function c:getSerialID()
    return ids.RECT
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

--String description of point
function c:__tostring()
    return string.format( "[%d,%d,%d,%d]", self.l, self.t, self.r, self.b )
end

class.register( "rect", c )

serialize.register( function( serialID ) return new.rect( 0, 0, 0, 0 ) end, ids.RECT )