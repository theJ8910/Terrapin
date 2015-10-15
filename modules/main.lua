require( "map" )
require( "panel" )
require( "mapPanel" )
require( "graphics" )
require( "vector" )
require( "rect" )
require( "timer" )

local changed = false

local g
local m
local rootPanel

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

--Event processing loop
function eventProc()
    while true do
        local event, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()
        --number intID
        if event == "timer" then
            timer.handle( arg1 )
        --number scancode, boolean is_held
        elseif event == "key" then
            --Tilda exits the program (I'd make it escape, but that's the key ComputerCraft uses to leave its GUI)
            if arg1 == 41 then return end

            rootPanel:dispatch( "key", arg1, arg2 )
        --number scancode, boolean is_held
        elseif event == "key_up" then
            rootPanel:dispatch( "key_up", arg1, arg2 )
        --number button, number x, number y
        elseif event == "mouse_click" then
            rootPanel:dispatch( "mouse_click", arg1, arg2, arg3 )
        --number button, number x, number y
        elseif event == "mouse_up" then
            rootPanel:dispatch( "mouse_up", arg1, arg2, arg3 )
        --number button, number x, number y
        elseif event == "mouse_drag" then
            rootPanel:dispatch( "mouse_drag", arg1, arg2, arg3 )
        --number dir (-1=up,1=down), number x, number y
        elseif event == "mouse_scroll" then
            rootPanel:dispatch( "mouse_scroll", arg1, arg2, arg3 )
        end
    end
end

function display()
    while true do        
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
    
    parallel.waitForAny( display, eventProc )
end

function __init()
    --Make graphics, map, and map panel
    local w, h = term.getSize()
    g = new.graphics( w, h )
    m = new.map()
    rootPanel = new.mapPanel( m )
    rootPanel:setBounds( new.rect( 0, 0, w, h ) )
end

function __cleanup()
    rootPanel:destroy()
    g:reset()
end