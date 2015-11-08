require( "ui.panel" )
require( "math2.vector" )
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
    [4] = {
        ["name"] = "Water",
        ["char"] = "~",
        ["fg"]   = colors.cyan,
        ["bg"]   = colors.blue
    },
    [5] = {
        ["name"] = "Lava",
        ["char"] = "~",
        ["fg"]   = colors.orange,
        ["bg"]   = colors.red
    },
    [6] = {
        ["name"] = "Dirt",
        ["char"] = " ",
        ["fg"]   = colors.lightGray,
        ["bg"]   = colors.brown
    },
    [7] = {
        ["name"] = "Grass",
        ["char"] = " ",
        ["fg"]   = colors.lime,
        ["bg"]   = colors.green
    },
    [8] = {
        ["name"] = "Stone",
        ["char"] = "#",
        ["fg"]   = colors.lightGray,
        ["bg"]   = colors.gray
    },
    [9] = {
        ["name"] = "Cobblestone",
        ["char"] = "%",
        ["fg"]   = colors.lightGray,
        ["bg"]   = colors.gray
    },
    [10] = {
        ["name"] = "Coal Ore",
        ["char"] = "#",
        ["fg"]   = colors.black,
        ["bg"]   = colors.gray
    },
    [11] = {
        ["name"] = "Iron Ore",
        ["char"] = "#",
        ["fg"]   = colors.orange,
        ["bg"]   = colors.gray
    },
    [12] = {
        ["name"] = "Gold Ore",
        ["char"] = "#",
        ["fg"]   = colors.yellow,
        ["bg"]   = colors.gray
    },
    [13] = {
        ["name"] = "Diamond Ore",
        ["char"] = "#",
        ["fg"]   = colors.cyan,
        ["bg"]   = colors.gray
    },
    [14] = {
        ["name"] = "Lapis Lazuli Ore",
        ["char"] = "#",
        ["fg"]   = colors.blue,
        ["bg"]   = colors.gray
    },
    [15] = {
        ["name"] = "Redstone Ore",
        ["char"] = "#",
        ["fg"]   = colors.red,
        ["bg"]   = colors.gray
    },
    [16] = {
        ["name"] = "Oak Wood",
        ["char"] = "O",
        ["fg"]   = colors.yellow,
        ["bg"]   = colors.brown
    },
    [17] = {
        ["name"] = "Oak Leaves",
        ["char"] = "$",
        ["fg"]   = colors.lime,
        ["bg"]   = colors.green
    },
    [18] = {
        ["name"] = "Oak Wood Planks",
        ["char"] = "=",
        ["fg"]   = colors.yellow,
        ["bg"]   = colors.brown
    },
    [19] = {
        ["name"] = "Torch",
        ["char"] = "i",
        ["fg"]   = colors.yellow,
        ["bg"]   = colors.black
    },
    [20] = {
        ["name"] = "Chest",
        ["char"] = "X",
        ["fg"]   = colors.black,
        ["bg"]   = colors.brown
    },
    [21] = {
        ["name"] = "Computer",
        ["char"] = ">",
        ["fg"]   = colors.white,
        ["bg"]   = colors.gray
    },
    [22] = {
        ["name"] = "Advanced Computer",
        ["char"] = ">",
        ["fg"]   = colors.white,
        ["bg"]   = colors.yellow
    }
}

local dirtChars  = { { 0.50, " " }, { 0.16, "." }, { 0.16, "," },  { 0.16, "'" } }
local grassChars = { { 0.50, " " }, { 0.16, "`" }, { 0.16, "\"" }, { 0.16, "'" } }

--Pick a random character based on x, y, z from choices
local function randomChar( x, y, z, choices )
    math.randomseed( 1249*x + 5984*y + 2952*z )
    local r = math.random()
    local s = 0
    for i,v in ipairs( choices ) do
        s = s + v[1]
        if r < s then return v[2] end
    end
    return choices[#choices][2]
end
--local liquidAnim = { "_","=","-","~"," " }

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

    self.dragging     = false
    self.cameraWasAt  = new.point( 0, 0 )
    self.draggingFrom = new.point( 0, 0 )
    
    --Make the controls on the map panel blink
    self.timerid = timer.repeating( 0.5, function()
        self.blink = not self.blink
        self:redraw()
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
                self:redraw()
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

function c:isFocusable()
    return true
end

local keyPressHandlers = {
    [203] = function( self ) self.camera.x = self.camera.x - 1; self:redraw() end,    --Left arrow
    [205] = function( self ) self.camera.x = self.camera.x + 1; self:redraw() end,    --Right arrow
    [200] = function( self ) self.camera.z = self.camera.z - 1; self:redraw() end,    --Up arrow
    [208] = function( self ) self.camera.z = self.camera.z + 1; self:redraw() end,    --Down arrow
    [51]  = function( self ) self.camera.y = math.min( self.camera.y + 1, 255 ); self:redraw() end,    --Left angle bracket
    [52]  = function( self ) self.camera.y = math.max( self.camera.y - 1, 0   ); self:redraw() end,    --Right angle bracket
}

function c:onKeyDown( scancode, held )
    local handler = keyPressHandlers[ scancode ]
    if handler == nil then return false end
    
    handler( self )
    return true
end

function c:onMouseDown( x, y, button )
    if button ~= 1 then return false end --1 = left mouse button

    local w, h = self:getBounds():getSize()
    local hw = math.floor( (w-1)/2 )
    local hh = math.floor( (h-1)/2 )

    if     x == hw     and y == 0     then keyPressHandlers[200]( self )
    elseif x == hw     and y == h - 1 then keyPressHandlers[208]( self )
    elseif x == 0      and y == hh    then keyPressHandlers[203]( self )
    elseif x == w - 1  and y == hh    then keyPressHandlers[205]( self )
    else
        self:setMouseCapture( true )
        self.dragging       = true
        self.cameraWasAt.x  = self.camera.x
        self.cameraWasAt.y  = self.camera.z
        self.draggingFrom.x = x
        self.draggingFrom.y = y
    end
    return true
end

function c:onMouseUp( x, y, button )
    if button ~= 1 or not self.dragging then return false end --1 = left mouse button
    self:setMouseCapture( false )
    self.dragging = false
    return true
end

function c:onMouseDrag( x, y, button )
    if button ~= 1 or not self.dragging then return false end --1 = left mouse button

    self.camera.x = self.cameraWasAt.x + self.draggingFrom.x - x
    self.camera.z = self.cameraWasAt.y + self.draggingFrom.y - y
    self:redraw()
    return true
end

function c:onMouseScroll( x, y, dir )
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
            local block = self.map:getBlock( px, cy, pz )
            local ch, fg, bg = getRenderInfo( block )
            if     block == 6 then ch = randomChar( px, cy, pz, dirtChars  )
            elseif block == 7 then ch = randomChar( px, cy, pz, grassChars )
            end
            context:setCharacter( ch )
            context:setForeground( fg )
            context:setBackground( bg )
            context:draw( x, y )
            px = px + 1
        end
        px = xbegin
        pz = pz + 1
    end

    --Camera position & block info
    context:setForeground( colors.white )
    context:setBackground( colors.red )
    context:drawText( 0, 0, string.format( "%d,%d,%d", cx, cy, cz ) )
    context:drawText( 0, 1, builtinBlocks[ self.map:getBlock( cx, cy, cz ) ].name )

    --Controls
    if self.blink then
        local hw = math.floor( (w-1)/2 )
        local hh = math.floor( (h-1)/2 )
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