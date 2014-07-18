require( "class" )
require( "vector" )
require( "panel" )

local builtinBlocks = {
    [0] = {
        ["name"] = "Shroud",
        ["char"] = "#",
        ["fg"] = colors.gray,
        ["bg"] = colors.black
    },
    [1] = {
        ["name"] = "Air",
        ["char"] = " ",
        ["fg"] = colors.yellow,
        ["bg"] = colors.black
    },
    [2] = {
        ["name"] = "Unknown Liquid",
        ["char"] = "~",
        ["fg"] = colors.yellow,
        ["bg"] = colors.black
    },
    [3] = {
        ["name"] = "Unknown Solid",
        ["char"] = "+",
        ["fg"] = colors.yellow,
        ["bg"] = colors.black
    },
}

--Returns the character, foreground color, and background color of a block with the given ID.
local function getRenderInfo( blockID )
    local b = builtinBlocks[ blockID ]
    if b == nil then error( string.format( "Unrecognized block ID: %d", blockID ) ) end

    return b.char, b.fg, b.bg
end

--Returns the x and z coordinates of the block in the upper-left corner of the panel
local function getMapCoordinates( cameraX, cameraZ, w, h )
    return math.floor( cameraX - w / 2 + 1 ),   --xbegin
           math.floor( cameraZ - h / 2 + 1 )    --zbegin
end

--mapPanel
local c = {}

function c:init( m )
    self.base.init( self )
    self.map = m
    self.camera = new.vector( 0, 0, 0 )
    
    --When a visible tile on the map changes, tell us so we know the map needs to be redrawn
    m:addMapListener(
        function( pos, block )
            local b = self:getBounds()
            local w = b:getWidth()
            local h = b:getHeight()
            local x,z = getMapCoordinates( self.camera.x, self.camera.z, w, h )
            
            --We only care about tiles the panel can currently see
            if pos.x >= x and pos.x < x + w and
               pos.z >= z and pos.z < z + h and
               pos.y == pos.y then
                panel.needsUpdate()
            end
        end
    )
end

function c:setCamera( camera )
    self.camera = camera
end

function c:getCamera()
    return self.camera
end

local keyPressHandlers = {
    [203] = function( self ) self.camera.x = self.camera.x - 1; panel.needsUpdate() end,    --Left arrow
    [205] = function( self ) self.camera.x = self.camera.x + 1; panel.needsUpdate() end,    --Right arrow
    [200] = function( self ) self.camera.z = self.camera.z - 1; panel.needsUpdate() end,    --Up arrow
    [208] = function( self ) self.camera.z = self.camera.z + 1; panel.needsUpdate() end,    --Down arrow
    [51]  = function( self ) self.camera.y = math.min( self.camera.y + 1, 255 ); panel.needsUpdate() end,    --Left angle bracket
    [52]  = function( self ) self.camera.y = math.max( self.camera.y - 1, 0   ); panel.needsUpdate() end,    --Right angle bracket
}

function c:key( scancode )
    local handler = keyPressHandlers[ scancode ]
    if handler == nil then return false end
    
    handler( self )
    return true
end

function c:draw( context )
    local b = self:getBounds()
    local w = b:getWidth()
    local h = b:getHeight()
    
    local xbegin, zbegin = getMapCoordinates( self.camera.x, self.camera.z, w, h )
    local p = new.vector( xbegin, self.camera.y, zbegin )
    for y=0, h-1 do
        for x=0, w-1 do
            local ch, fg, bg = getRenderInfo( self.map:getBlock( p ) )
            context:draw( x, y, ch, fg, bg )
            p.x = p.x + 1
        end
        p.x = xbegin
        p.z = p.z + 1
    end
end

class.register( "mapPanel", c, "panel" )