require( "map" )
require( "panel" )
require( "mapPanel" )
require( "graphics" )
require( "vector" )
require( "rect" )
require( "timer" )
require( "device" )
require( "comms" )

local changed = false

local g
local m
local rootPanel

--Event processing loop
function eventProc()
    --A note on how events work in ComputerCraft:
    --Everything that happens in ComputerCraft runs inside of a coroutine started at the time the Lua instance is created; it's the "main thread" so to speak.
    --This coroutine is only allowed to run uninterrupted for 7 seconds; before that, it must yield or be forcefully yielded by ComputerCraft.
    --While the coroutine is running, events cannot be processed and are put into an internal queue.
    --When the coroutine yields, ComputerCraft takes this opportunity to process any pending events for this computer.
    --When an event is processed, it resumes the coroutine, passing details about the event as arguments. These are returned from the previous call to coroutine.yield().
    --os.pullEvent() seems to call coroutine.yield() internally; when the coroutine is resumed and the event is not in the filter, it is discarded and the coroutine goes back to sleep.
    --parallel.waitForAll / parallel.waitForAny creates a coroutine for each function given to it. When every function has yielded, parallel.waitForAll / parallel.waitForAny yields,
    --waiting for the next event to arrive. When this event arrives, it resumes the coroutines if they pass the coroutine's filter (returned by coroutine.yield() inside of os.pullEvent()).
    --If multiple coroutines pass this filter, then all of those coroutines will be passed a copy of the event.
    --There seems to be no danger in events being lost so long as one coroutine is available to process them; therefore the event loop coroutine should only yield here in this function.
    while true do
        local event, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()
        --number intID
        --string side, number receiving channel, number reply channel, any message, number distance
        if event == "modem_message" then
            comms.handle( arg1, arg2, arg3, arg4, arg5 )
        --number id
        elseif event == "timer" then
            timer.handle( arg1 )
        --number scancode, boolean is_held
        elseif event == "key" then
            --Q exits the program (I'd make it escape, but that's the key ComputerCraft uses to leave its GUI)
            if     arg1 == 16 then return
            --TEMP: tilde opens a console we can output log messages to
            elseif arg1 == 41 then shell.openTab( "console.lua" )
            end

            rootPanel:keyDispatch( "onKeyDown", arg1, arg2 )
        --number scancode, boolean is_held
        elseif event == "key_up" then
            rootPanel:keyDispatch( "onKeyUp", arg1, arg2 )
        --number button, number x, number y
        elseif event == "mouse_click" then
            rootPanel:rootMouseDispatch( "onMouseDown", arg2 - 1, arg3 - 1, arg1 )
        --number button, number x, number y
        elseif event == "mouse_up" then
            rootPanel:rootMouseDispatch( "onMouseUp", arg2 - 1, arg3 - 1, arg1 )
        --number button, number x, number y
        elseif event == "mouse_drag" then
            rootPanel:rootMouseDispatch( "onMouseDrag", arg2 - 1, arg3 - 1, arg1 )
        --number dir (-1=up,1=down), number x, number y
        elseif event == "mouse_scroll" then
            rootPanel:rootMouseDispatch( "onMouseScroll", arg2 - 1, arg3 - 1, arg1 )
        --string side
        elseif event == "peripheral" or event == "peripheral_detach" then
            device.update( arg1 )
        end
    end
end

--Display loop. Every few frames, we apply any necessary updates to the display.
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

local function onPeripheralAdded( side, t )
    if t == "modem" then comms.onModemAttached( side ) end
end

local function onPeripheralRemoved( side, t )
    if t == "modem" then comms.onModemDetached( side ) end
end

--Entry point for when we run the module
function __main()
    --When a panel is updated, tell us so we know to redraw
    panel.addUpdateListener( function() changed = true end )

    --Draw initial graphics
    rootPanel:drawAll( g:getContext() )
    g:redraw()

    --Start display and event processing threads
    parallel.waitForAny( display, eventProc )
end

--Initializes some things our program needs
function __init()
    device.addListener( "added",   onPeripheralAdded   )
    device.addListener( "removed", onPeripheralRemoved )
    device.scan()

    --Make graphics, map, and map panel
    local w, h = term.getSize()
    g = new.graphics( w, h )
    m = new.map()
    rootPanel = new.mapPanel( m )
    rootPanel:setBounds( new.rect( 0, 0, w, h ) )
end

--Cleans up our program before exiting from it
function __cleanup()
    rootPanel:destroy()
    g:reset()
end