require( "chunk" )
require( "vector" )
require( "util" )
require( "serialize" )
require( "ids" )

local c = {}

--Max number of chunks that can be loaded at a time
local chunkLimit = 512

local function getChunkPath( x, z )
    return string.format( "chunks/chunk_%d_%d.bin", x, z )
end

local function getChunkHash( x, z )
    return x + z * 65536
end

function c:init()
    self.chunks = {}
    self.chunksByLoadOrder = {}
    
    self.mapListeners = {}
end

function c:addMapListener( fn )
    self.mapListeners[fn] = true
end

function c:removeMapListener( fn )
    self.mapListeners[fn] = nil
end

function c:eventMapListener( pos, block )
    for k,v in pairs( self.mapListeners ) do
        pcall( k, pos, block )
    end
end

function c:setBlock( x, y, z, block )
    local chunkx = math.floor( x / 16 )
    local chunkz = math.floor( z / 16 )
    local chunk  = self:getChunk( chunkx, chunkz )
    
    chunk:setBlock( x % 16, y, z % 16, block )
end

function c:getBlock( x, y, z )
    local chunkx = math.floor( x / 16 )
    local chunkz = math.floor( z / 16 )
    local chunk  = self:getChunk( chunkx, chunkz )
    
    return chunk:getBlock( x % 16, y, z % 16 )
end

function c:getChunk( x, z )
    local hash  = getChunkHash( x, z )
    local chunk = self.chunks[ hash ]
    
    --If this chunk isn't loaded, we need to load it
    if chunk == nil then
    
        --Save and unload the oldest chunk if we're at the limit to make way for the new chunk
        if #self.chunksByLoadOrder == chunkLimit then
            local chunk2 = self.chunksByLoadOrder[1]
            
            local fw = serialize.fileWriter( getChunkPath( chunk2.x, chunk2.z ) )
            fw:writeObject( chunk2 )
            fw:close()
            
            self.chunks[ getChunkHash( chunk2.x, chunk2.z ) ] = nil
            table.remove( self.chunksByLoadOrder, 1 )
        end
        
        --Check to see if the chunk exists.
        --If not, we'll create a new chunk
        local path = getChunkPath( x, z )
        if fs.exists( path ) then
            local fr = serialize.fileReader( path )
            chunk = fr:readObject()
            fr:close()
        else
            chunk = new.chunk( x, z )
        end
        
        --Store the chunk in memory for future use
        self.chunks[ hash ] = chunk
        table.insert( self.chunksByLoadOrder, chunk )
        
    end
    return chunk
end

function c:getSerialID()
    return ids.MAP
end

function c:save( writer )

end

function c:load( loader )

end

class.register( "map", c )

serialize.register( function( serialID ) return new.map() end, ids.MAP )

--[[
local blocks = {}

local blockname = {
   [-1 ] = "Air",
   [ 0 ] = "Shroud",
   [ 1 ] = "Not Identified",
   [ 2 ] = "Cobblestone",
   [ 3 ] = "Mossy Cobblestone",
   [ 4 ] = "Stone",
   [ 5 ] = "Stone Brick",
   [ 6 ] = "Clay Brick",
   [ 7 ] = "Dirt",
   [ 8 ] = "Grass",
   [ 9 ] = "Sand",
   [ 10] = "Gravel",
   [ 11] = "Coal",
   [ 12] = "Iron",
   [ 13] = "Gold",
   [ 14] = "Diamond",
   [ 15] = "Lapis Lazuli",
   [ 16] = "Redstone",
   [ 17] = "Copper (IC)",
   [ 18] = "Copper (RP)",
   [ 19] = "Tin (IC)",
   [ 20] = "Tin (RP)",
   [ 21] = "Uranium",
   [ 22] = "Ruby",
   [ 23] = "Emerald",
   [ 24] = "Sapphire",
   [ 25] = "Silver",
   [ 26] = "Nikolite",
   [ 27] = "Tungsten",
   [ 28] = "Oakwood Log",
   [ 29] = "Oakwood Planks",
   [ 30] = "Pine Log",
   [ 31] = "Pine Planks",
   [ 32] = "Birch Log",
   [ 33] = "Birch Planks",
   [ 34] = "Jungle Log",
   [ 35] = "Jungle Planks",
   [ 36] = "Torch"
}

local blocksymbol = {
    [-1 ] = " ",
    [ 0 ] = "#",
    [ 1 ] = "?",
    [ 2 ] = "-",
    [ 3 ] = "=",
    [ 4 ] = "+",
    [ 9 ] = "$",
    [ 10] = "$",
    [ 11] = "$",
    [ 12] = "$",
    [ 13] = "$",
    [ 14] = "$",
    [ 15] = "$",
    [ 16] = "$",
    [ 17] = "$",
    [ 18] = "$",
    [ 19] = "$",
    [ 20] = "$",
    [ 21] = "$",
    [ 22] = "$",
    [ 23] = "$",
    [ 24] = "$",
    [ 25] = "$",
    [ 29] = "H",
    [ 31] = "H",
    [ 33] = "H",
    [ 35] = "H",
    [ 36] = "i"
}

function set( pos, type )
    if not blocks[pos.x] then
        blocks[pos.x] = {}
    end
    if not blocks[pos.x][pos.y] then
        blocks[pos.x][pos.y] = {}
    end
    blocks[pos.x][pos.y][pos.z] = type
end

function get( pos )
    return ( blocks[pos.x] and
             blocks[pos.x][pos.y] and
             blocks[pos.x][pos.y][pos.z]
           ) or 0
end

--Have we examined this tile yet
function visible( pos )
    return ( blocks[pos.x] and
             blocks[pos.x][pos.y] and
             blocks[pos.x][pos.y][pos.z]
           ) ~= nil
end

--Is every tile around the given tile visible
function surroundings_visible( pos )
    return map.visible( coords.v( pos.x + 1, pos.y,     pos.z     ) ) and
           map.visible( coords.v( pos.x - 1, pos.y,     pos.z     ) ) and
           map.visible( coords.v( pos.x,     pos.y + 1, pos.z     ) ) and
           map.visible( coords.v( pos.x,     pos.y - 1, pos.z     ) ) and
           map.visible( coords.v( pos.x,     pos.y,     pos.z + 1 ) ) and
           map.visible( coords.v( pos.x,     pos.y,     pos.z - 1 ) )
end

function getname( type )
    return blockname[type] or "Unnamed"
end

function getsymbol( type )
    return blocksymbol[type] or "?"
end

--os.pullEvent("key")
--203 = left
--205 = right
--200 = up
--208 = down
--51  = <
--52  = >

function view( x, y, z )
    x = x or 0
    y = y or 0
    z = z or 0
    
    local running = true
    local blink = true
    local tw, th = term.getSize()
    local key
    local desc
    local xs
    local centerx = math.floor(tw/2)
    local centery = math.floor(th/2)
    
    repeat
        term.clear()
        term.setCursorPos(1,1)
        desc = tostring(x)..", "..tostring(y)..", "..tostring(z)..": "..getname( get( coords.v( x, y, z ) ) )
        term.write( desc )
        
        for cy = 1, th do
            if cy == 1 then xs = 1 + string.len( desc )
            else            xs = 1
            end
            for cx = xs, tw do
                term.setCursorPos( cx, cy )
                term.write(
                    getsymbol(
                        get( coords.v( x - centerx + cx,
                                       y + centery - cy,
                                       z
                            )
                        )
                    )
                )
            end
        end
        
        if blink then
            term.setCursorPos( centerx, centery )
            term.write( "*" )
        end
        
        local function inputfn()
            local etype, key = os.pullEvent( "key" )
            
            if     key == 203 then x = x - 1        --left
            elseif key == 205 then x = x + 1        --right
            elseif key == 200 then y = y + 1        --up
            elseif key == 208 then y = y - 1        --down
            elseif key == 52  then z = z - 1        -->
            elseif key == 51  then z = z + 1        --<
            elseif key == 28  then running = false  --enter
            end
        end
        
        local function blinkfn()
            --Start a timer
            local t = os.startTimer( 0.5 )
            
            --Wait until it occurs
            local etype, t2
            repeat etype, t2 = os.pullEvent( "timer" ) until t2 == t
            
            --Blink the cursor
            blink = not blink
        end
        
        local function updatefn()
            os.pullEvent( "mapupdate" )
        end
        
        parallel.waitForAny( inputfn, blinkfn, updatefn )
    until not running
    
    term.clear()
    term.setCursorPos(1,1)
end
]]--