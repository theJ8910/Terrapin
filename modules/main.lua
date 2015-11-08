require( "timer" )
require( "device" )
require( "comms" )
require( "graphics" )
require( "ui.rootPanel" )
require( "ui.box" )
require( "map" )
require( "mapPanel" )
require( "math2.rect" )
require( "log" )

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
            elseif arg1 == 41 then
                --NOTE: shell.openTab() blocks until the process you run yields for the first time,
                --so we can be confident that log.set() has been called before running log.redirect().
                shell.openTab( "console.lua" )
                log.redirect()
            end

            rootPanel:keyboardDispatch( "onKeyDown", arg1, arg2 )
        --number scancode, boolean is_held
        elseif event == "key_up" then
            rootPanel:keyboardDispatch( "onKeyUp", arg1, arg2 )
        --number button, number x, number y
        elseif event == "mouse_click" then
            rootPanel:mouseDispatch( "onMouseDown", arg2 - 1, arg3 - 1, arg1 )
        --number button, number x, number y
        elseif event == "mouse_up" then
            rootPanel:mouseDispatch( "onMouseUp", arg2 - 1, arg3 - 1, arg1 )
        --number button, number x, number y
        elseif event == "mouse_drag" then
            rootPanel:mouseDispatch( "onMouseDrag", arg2 - 1, arg3 - 1, arg1 )
        --number dir (-1=up,1=down), number x, number y
        elseif event == "mouse_scroll" then
            rootPanel:mouseDispatch( "onMouseScroll", arg2 - 1, arg3 - 1, arg1 )
        --string side
        elseif event == "peripheral" or event == "peripheral_detach" then
            device.update( arg1 )
        --string side
        elseif event == "monitor_resize" then
            --TODO
        --no args
        elseif event == "term_resize" then
            --NOTE: A "term_resize" event is received when the terminal for _the tab the program is running in_ resizes.
            --We currently assume the UI is being rendered to this terminal.
            --If our UI is on a monitor, or being rendered to a different tab's terminal, this becomes more complicated.
            g:onTerminalResized()
            rootPanel:onTerminalResized()
        end
    end
end

--Display loop. Every few frames, we apply any necessary updates to the display.
function display()
    while true do
        --Update layout if necessary
        rootPanel:layout()

        --Redraw panels if necessary
        if rootPanel:getNeedsRedraw() then
            rootPanel:drawAll( g:getContext() )
            g:draw()
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

--Initializes some things our program needs
function __init()
    --Init graphics & UI
    local term = term.current()
    g = new.graphics( term )
    rootPanel = new.rootPanel( term )

    --Make map and map panel
    m = new.map()
    mp = new.mapPanel( m )
    mp:setParent( rootPanel )
end

--Entry point for when we run the module
function __main()
    --Register listeners
    device.addListener( "added",   onPeripheralAdded   )
    device.addListener( "removed", onPeripheralRemoved )
    device.scan()

    --Draw initial graphics
    rootPanel:drawAll( g:getContext() )
    g:redraw()

    --Start display and event processing threads
    parallel.waitForAny( display, eventProc )
end

--Cleans up our program before exiting from it
function __cleanup()
    --Remove listeners
    device.removeListener( "added",   onPeripheralAdded   )
    device.removeListener( "removed", onPeripheralRemoved )

    rootPanel:destroy()
    g:reset()
end