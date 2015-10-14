require( "map" )
require( "panel" )
require( "mapPanel" )
require( "graphics" )
require( "vector" )
require( "rect" )

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

local timers = {}

--Runs fn after delay seconds have passed (actual time may be longer than what was specified).
local function setTimeout( delay, fn )
    timers[ os.startTimer( delay ) ] = fn
end

--Event processing loop
function eventProc()
    while true do
        local event, arg1 = os.pullEvent()
        if event == "key" then
            --Tilda exits the program (I'd make it escape, but that's the key ComputerCraft uses to leave its GUI)
            if arg1 == 41 then return end

            rootPanel:dispatch( "key", arg1 )
        elseif event == "timer" then
            local fn = timers[arg1]
            timers[arg1] = nil
            if fn ~= nil then fn() end
        end
    end
end

local changed = false
function display()
    local c = g:getContext()
    c:setForeground( colors.black )
    c:setBackground( colors.red )
    c:setCharacter( "*" )

    while true do        
        if changed then
            rootPanel:drawAll( g:getContext() )
            g:draw()
            changed = false
        end

        --c:draw( math.random( 0, w-1 ), math.random( 0, h-1 ) )
        --g:draw()
        
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

    --TEMP: Make the controls on the map panel blink
    local f
    f = function()
        rootPanel.blink = not rootPanel.blink
        panel.needsUpdate()
        setTimeout( 0.5, f )
    end
    setTimeout( 0.5, f )
    
    parallel.waitForAny( display, eventProc )
end

function __cleanup()
    g:reset()
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