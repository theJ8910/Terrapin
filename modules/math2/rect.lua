--One of two classes for representing rectangles, rect.
--Stores l, t, r, and b values internally (left, top, right, and bottom respectively).
--A rect is considered valid if l <= r and t <= b.
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

--Returns a copy of this rect
function c:copy()
    return new.rect(
        self.l,
        self.t,
        self.r,
        self.b
    )
end

--Converts this rect( l, t, r, b ) to a bounds( x, y, w, h )
function c:toBounds()
    return new.bounds(
        self.l,
        self.t,
        self.r - self.l,
        self.b - self.t
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

--Returns the x and y coordinates of the top-left corner of the rect
function c:getPos()
    return self.l, self.t
end

--Returns the width of the rect
function c:getWidth()
    return self.r - self.l
end

--Returns the height of the rect
function c:getHeight()
    return self.b - self.t
end

--Returns the width and height of the rect
function c:getSize()
    return self.r - self.l, self.b - self.t
end

--Creates and returns a smaller rect by moving this rect's l, t, r, and b inwards by the given values.
--All arguments are expected to be non-negative.
--If the resulting rect is invalid (i.e. l > r or t > b) then new.rect(0,0,0,0) is returned.
function c:collapse( l, t, r, b )
    l = self.l + l
    t = self.t + t
    r = self.r - r
    b = self.b - b

    if l > r or t > b then return new.rect( 0, 0, 0, 0 ) end
    return new.rect( l, t, r, b )
end

--Createss and returns a larger rect by moving this rect's l, t, r, and b outwards by the given values.
--All arguments are expected to be non-negative.
function c:expand( l, t, r, b )
    return new.rect(
        self.l - l,
        self.t - t,
        self.r + r,
        self.b + b
    )
end

--Returns the area of the rectangle.
function c:area()
    return ( self.r - self.l ) * ( self.b - self.t )
end

--Returns true if l == r and/or t == b; in other words, if the rectangle has no area.
--Returns false otherwise.
function c:isEmpty()
    return self.l == self.r or self.t == self.b
end

--Returns true if l == t == r == b == 0.
--Returns false otherwise.
function c:isZero()
    return self.l == 0 and
           self.t == 0 and
           self.r == 0 and
           self.b == 0
end

--Returns true if l <= r and/or t <= b.
function c:isValid()
    return self.l <= self.r and self.t <= self.b
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