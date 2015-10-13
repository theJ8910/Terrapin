require( "map" )
require( "panel" )
require( "mapPanel" )
require( "graphics" )
require( "vector" )
require( "rect" )

running = true

local w, h = term.getSize()
g = new.graphics( w, h )

m = new.map()
rootPanel = new.mapPanel( m )
rootPanel:setBounds( new.rect( 0, 0, w, h ) )

local scanTypeToBlockType = {
    ["AIR"]    = 1,
    ["LIQUID"] = 2,
    ["SOLID"]  = 3
}

function scan( pname, ploc )
    local p = peripheral.wrap( pname )
    local results = p.sonicScan()
    for k,v in pairs( results ) do
        m:setBlock( ploc + v, scanTypeToBlockType[v.type] )
    end
end

local kp = {}
function keyPress()
    while running do
        local event, scancode = os.pullEvent( "key" )
        table.insert( kp, scancode )
    end
end

local changed = false
function scheduler()
    while running do
        --Dispatch keys
        for k,v in ipairs( kp ) do
            rootPanel:dispatch( "key", v )
        end
        kp = {}
        
        if changed then
            rootPanel:drawAll( g:getContext() )
            g:draw()
            changed = false
        end
        
        --Update framerate as necessary
        os.sleep( 0.01 )
    end
end

function __main()
    --When a panel is updated, tell us so we know to redraw
    panel.addUpdateListener( function() changed = true end )
    
    --Draw initial graphics
    rootPanel:drawAll( g:getContext() )
    g:redraw()
    
    parallel.waitForAll( scheduler, keyPress )
end

--[[
local blinked = true
function blink()
    while running do
        os.sleep( 0.5 )
        blinked = not blinked
        drawMap()
    end
end
]]--

--[[
function drawMap()
    local w, h = term.getSize()
    local xbegin = math.floor( cameraPos.x - w / 2 + 1 )
    local zbegin = math.floor( cameraPos.z - h / 2 + 1 )
    
    --2/2 = 1;       0, 1
    --3/2 = 1.5; -1, 0, 1
    --4/2 = 2;   -1, 0, 1, 2
    
    local p = vector.new( xbegin, cameraPos.y, zbegin )
    for y = 1, h do
        for x = 1, w do
            draw( m:getBlock( p ), x, y  )
            p.x = p.x + 1
        end
        p.x = xbegin
        p.z = p.z + 1
    end
    
    term.setTextColor( colors.white )
    term.setBackgroundColor( colors.black )
    
    term.setCursorPos( 1, 1 )
    term.write( string.format( "%d,%d,%d", cameraPos.x, cameraPos.y, cameraPos.z ) )
    
    term.setCursorPos( 1, 2 )
    term.write( string.format( "%s", builtinBlocks[ m:getBlock( cameraPos ) ].name ) )
    
    if blinked then
        local hw = math.ceil( w/2 )
        local hh = math.ceil( h/2 )
        
        term.setCursorPos( hw, hh )
        term.write( "x" )
        
        term.setCursorPos( 1, hh )
        term.write( "<" )
        
        term.setCursorPos( w, hh )
        term.write( ">" )
        
        term.setCursorPos( hw, 1 )
        term.write( "^" )
        
        term.setCursorPos( hw, h )
        term.write( "v" )
    end
end
]]--