require( "serialize" )
require( "ids" )

local c = {}

function c:init( x, y, z )
    self.x = x
    self.y = y
    self.z = z
end

function c:copy()
    return new.vector( self.x, self.y, self.z )
end

function c:set( x, y, z )
    self.x = x
    self.y = y
    self.z = z
end

function c:get()
    return self.x, self.y, self.z
end

--Check if two vectors are equal
function c:__eq( other )
    return self.x == other.x and
           self.y == other.y and
           self.z == other.z
end

--Add two vectors
function c:__add( other )
    return new.vector(
        self.x + other.x,
        self.y + other.y,
        self.z + other.z
    )
end

--Subtract two vectors
function c:__sub( other )
    return new.vector(
        self.x - other.x,
        self.y - other.y,
        self.z - other.z
    )
end

--Multiply by scalar
function c:__mul( s )
    return new.vector(
        self.x * s,
        self.y * s,
        self.z * s
    )
end

--Divide by scalar
function c:__div( s )
    return new.vector(
        self.x / s,
        self.y / s,
        self.z / s
    )
end

--String description of vector
function c:__tostring()
    return string.format( "<%d,%d,%d>", self.x, self.y, self.z )
end

function c:getSerialID()
    return ids.VECTOR
end

function c:save( writer )
    writer:writeNumber( self.x )
    writer:writeNumber( self.y )
    writer:writeNumber( self.z )
end

function c:load( reader )
    self.x = reader:readNumber()
    self.y = reader:readNumber()
    self.z = reader:readNumber()
end

class.register( "vector", c )

serialize.register( function( serialID ) return new.vector( 0, 0, 0 ) end, ids.VECTOR )

--Square of the distance between two points
function sqDistance( v1, v2 )
    local xOff = v2.x - v1.x
    local yOff = v2.y - v1.y
    local zOff = v2.z - v1.z
    return xOff*xOff + yOff*yOff + zOff*zOff
end

--Distance between two points
function distance( v1, v2 )
    return math.sqrt( sqDistance( v1, v2 ) )
end

--Manhattan distance between two points
function manhattan( v1, v2 )
    return math.abs( v2.x - v1.x ) +
           math.abs( v2.y - v1.y ) +
           math.abs( v2.z - v1.z )
end

--position s tiles in the direction "dir" of pos
function offset( pos, dir, s )
    return new.vector(
        pos.x + s * dir.x,
        pos.y + s * dir.y,
        pos.z + s * dir.z
    )
end

--position 1 tile to the north of pos
function northFrom( pos )
    return new.vector( pos.x, pos.y, pos.z - 1 )
end

--position 1 tile to the east of pos
function eastFrom( pos )
    return new.vector( pos.x + 1, pos.y, pos.z )
end

--position 1 tile to the south of pos
function southFrom( pos )
    return new.vector( pos.x, pos.y, pos.z + 1 )
end

--position 1 tile to the west of pos
function westFrom( pos )
    return new.vector( pos.x - 1, pos.y, pos.z )
end

--position 1 tile up of pos
function upFrom( pos )
    return new.vector( pos.x, pos.y + 1, pos.z )
end

--position 1 tile down of pos
function downFrom( pos )
    return new.vector( pos.x, pos.y - 1, pos.z )
end

function dot( v1, v2 )
    return v1.x * v2.x +
           v1.y * v2.y +
           v1.z * v2.z
end

function cross( v1, v2 )
    return new.vector(
        v1.y * v2.z - v1.z * v2.y,
        v1.z * v2.x - v1.x * v2.z,
        v1.x * v2.y - v1.y * v2.x
    )
end

EAST  = new.vector(  1,  0,  0 )
WEST  = new.vector( -1,  0,  0 )
NORTH = new.vector(  0,  0, -1 )
SOUTH = new.vector(  0,  0,  1 )
DOWN  = new.vector(  0, -1,  0 )
UP    = new.vector(  0,  1,  0 )