require( "serialize" )
require( "ids" )

--Returns a unique hash of the given vector
local function hashPos( v )
    return v.x + 16*v.y + 4096*v.z
end

local c = {}

function c:init( x, z )
    self.loaded     = false
    self.x = x
    self.z = z
    self.blocks     = {}
    self.blockCount = 0
end

function c:setLoaded( loaded )
    self.loaded = loaded
end

function c:getLoaded( loaded )
    self.loaded = loaded
end

function c:setX( x )
    self.x = x
end

function c:getX()
    return self.x
end

function c:setZ( z )
    self.z = z
end

function c:getZ()
    return self.z
end

function c:setBlock( pos, block )
    local h = hashPos( pos )
    local old = self.blocks[h]
    if old == nil and block ~= nil then
        self.blockCount = self.blockCount + 1
    elseif old ~= nil and block == nil then
        self.blockCount = self.blockCount - 1
    end
    self.blocks[ h ] = block
end

function c:getBlock( pos )
    local b = self.blocks[ hashPos( pos ) ]
    if b ~= nil then return b end
    
    --0 (shroud) is returned if there is no block set for the given position
    return 0
end

function c:getSerialID()
    return ids.CHUNK
end

function c:save( writer )
    writer:writeBool( self.loaded )
    writer:writeUnsignedInt16( self.x )
    writer:writeUnsignedInt16( self.z )
    writer:writeUnsignedInt16( self.blockCount )
    for k,v in pairs( self.blocks ) do
        writer:writeUnsignedInt16( k )
        writer:writeUnsignedInt16( v )
    end
end

function c:load( reader )
    self.loaded     = reader:readBool()
    self.x          = reader:readUnsignedInt16()
    self.z          = reader:readUnsignedInt16()
    self.blockCount = reader:readUnsignedInt16()
    for i = 1, self.blockCount do
        self.blocks[reader:readUnsignedInt16()] = reader:readUnsignedInt16()
    end
end

class.register( "chunk", c )

serialize.register( function( serialID ) return new.chunk( 0, 0 ) end, ids.CHUNK )