--One of two classes for representing rectangles, bounds.
--Stores x, y, w, and h values internally (x & y coordinates of the rectangle's upper-left corner, width, and height respectively).
--A bounds is considered valid if w > 0 and h > 0.
require( "serialize" )
require( "ids" )

--bounds
local c = {}

--Initializes a bounds with the given x, y, w, h values (expected)
function c:init( x, y, w, h )
    self.x = x
    self.y = y
    self.w = w
    self.h = h
end

--Returns a copy of this bounds
function c:copy()
    return new.bounds(
        self.x,
        self.y,
        self.w,
        self.h
    )
end

--Converts this bounds( x, y, w, h ) to a rect( l, t, r, b )
function c:toRect()
    return new.rect(
        self.x,
        self.y,
        self.x + self.w,
        self.y + self.h
    )
end

--Allows you to do bounds1 == bounds2 and bounds1 ~= bounds2
function c:__eq( other )
    return self.x == other.x and
           self.y == other.y and
           self.w == other.w and
           self.h == other.h
end

--Returns true if the point (x, y) is in this bounds, false otherwise
--Note: a point on (x,y) is included, a point on (x+w,y+h) is excluded (where x,y,w,h refer to the bounds' values).
function c:contains( x, y )
    return x >= self.x          and
           x <  self.x + self.w and
           y >= self.y          and
           y <  self.y + self.h
end

--Sets the x, y, width, and height of the rect
function c:set( x, y, w, h )
    self.x = x
    self.y = y
    self.w = w
    self.h = h
end

--Returns the left, top, right, and bottom of the rect
function c:get()
    return self.x, self.y, self.w, self.h
end

--Returns the x and y coordinates of the top-left corner of the bounds
function c:getPos()
    return self.x, self.y
end

--Returns the width of the bounds
function c:getWidth()
    return self.w
end

--Returns the height of the bounds
function c:getHeight()
    return self.h
end

--Returns the width and height of the bounds
function c:getSize()
    return self.w, self.h
end

--Returns the area of the bounds.
function c:area()
    return self.w * self.h
end

--Returns true if w == 0 and/or h == 0; in other words, if the bounds has no area.
--Returns false otherwise.
function c:isEmpty()
    return ( self.w * self.h ) == 0
end

--Returns true if w >= 0 and h >= 0.
function c:isValid()
    return self.w >= 0 and self.h >= 0
end

function c:getSerialID()
    return ids.BOUNDS
end

function c:save( writer )
    writer:writeNumber( self.x )
    writer:writeNumber( self.y )
    writer:writeNumber( self.w )
    writer:writeNumber( self.h )
end

function c:load( reader )
    self.x = reader:readNumber()
    self.y = reader:readNumber()
    self.w = reader:readNumber()
    self.h = reader:readNumber()
end

--String description of point
function c:__tostring()
    return string.format( "((%d,%d)[%dx%d])", self.x, self.y, self.w, self.h )
end

class.register( "bounds", c )

serialize.register( function( serialID ) return new.bounds( 0, 0, 0, 0 ) end, ids.BOUNDS )