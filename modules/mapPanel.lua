require( "vector" )
require( "panel" )
require( "timer" )

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
    self.blink = true

    self.cameraWasAt  = new.point( 0, 0 )
    self.draggingFrom = new.point( 0, 0 )
    
    --Make the controls on the map panel blink
    self.timerid = timer.repeating( 0.5, function()
        self.blink = not self.blink
        panel.needsUpdate()
    end )

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

function c:destroy()
    timer.cancel( self.timerid )
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

function c:mouse_click( button, x, y )
    local w, h = self:getBounds():getSize()
    local hw = math.floor( w/2 ) + 1
    local hh = math.floor( h/2 ) + 1

    if     x == hw and y == 1  then keyPressHandlers[200]( self )
    elseif x == hw and y == h  then keyPressHandlers[208]( self )
    elseif x == 1  and y == hh then keyPressHandlers[203]( self )
    elseif x == w  and y == hh then keyPressHandlers[205]( self )
    else
        self.cameraWasAt.x  = self.camera.x
        self.cameraWasAt.y  = self.camera.z
        self.draggingFrom.x = x
        self.draggingFrom.y = y
    end
    return true
end

function c:mouse_drag( button, x, y )
    self.camera.x = self.cameraWasAt.x + self.draggingFrom.x - x
    self.camera.z = self.cameraWasAt.y + self.draggingFrom.y - y
    panel.needsUpdate()
end

function c:mouse_scroll( dir, x, y )
    if     dir ==  1 then keyPressHandlers[51]( self )
    elseif dir == -1 then keyPressHandlers[52]( self )
    end
    return true
end

function c:draw( context )
    local cx, cy, cz = self.camera:get()
    local w, h = self:getBounds():getSize()
    
    local xbegin, zbegin = getMapCoordinates( self.camera.x, self.camera.z, w, h )
    local px, pz         = xbegin, zbegin
    for y=0, h-1 do
        for x=0, w-1 do
            local ch, fg, bg = getRenderInfo( self.map:getBlock( px, cy, pz ) )
            context:setCharacter( ch )
            context:setForeground( fg )
            context:setBackground( bg )
            context:draw( x, y )
            px = px + 1
        end
        px = xbegin
        pz = pz + 1
    end

    --Camera position
    
    context:setForeground( colors.white )
    context:setBackground( colors.red )
    context:drawText( 0, 0, string.format( "%d,%d,%d", cx, cy, cz ) )
    context:drawText( 0, 1, builtinBlocks[ self.map:getBlock( cx, cy, cz ) ].name )

    --Controls
    if self.blink then
        local hw = math.floor( w / 2 )
        local hh = math.floor( h / 2 )
        context:setForeground( colors.red   )
        context:setBackground( colors.black )

        context:setCharacter( "<" )
        context:draw( 0,   hh )

        context:setCharacter( ">" )
        context:draw( w-1, hh )

        context:setCharacter( "^" )
        context:draw( hw,  0 )

        context:setCharacter( "v" )
        context:draw( hw,  h-1 )

        context:setCharacter( "x" )
        context:draw( hw,  hh )
    end
end

class.register( "mapPanel", c, "panel" )