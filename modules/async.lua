--This module is necessary because of blocking functions.
--Certain ComputerCraft functions like turtle.forward(), turtle.attack(), etc. internally call os.pullEvent( "turtle_response" ),
--which causes the coroutine the blocking function was called on to yield until a "turtle_response" event is generated.
--Any other events generated during this time (such as modem messages) are ignored!
--If you were to call a blocking function on the same coroutine your event processing loop was on, this means we'd never see these events.
--By running blocking functions in a separate coroutine, we ensure that the event loop sees and has a chance to react to every event.

--Custom event used to indicate an action is available
local eventHaveTask = "theJ89_async_task"

--Store tasks in a queue until they can be processed
local tasks = {}

--Queue a task. This will be run asynchronously by taskProc.
--Tasks are executed in a first come, first serve order.
--callback is expected to be something callable (e.g. a function, a table with a __call metamethod, etc).
--You may provide additional arguments if desired. These will be passed to callback when it is executed.
function runLater( callback, ... )
    table.insert( tasks, { callback, ... } )

    --If the event queue was empty before, let taskProc know we've got events available to process
    if #tasks == 1 then os.queueEvent( eventHaveTask ) end
end

--This function contains a loop that repeatedly processes any asynchronous tasks we've queued up with async.runLater().
--If your program uses the async module, you should supply parallel.waitForAny / parallel.waitForAll with both this function and the function containing your event loop, e.g.:
--    parallel.waitForAny( eventProc, async.taskProc )
function taskProc()
    while true do
        --Wait for an action to become available
        os.pullEvent( eventHaveTask )
        while #pendingActions > 0 do
            local task = table.remove( tasks, 1 )

            --pcall so we don't crash the program if something goes wrong...
            local success, err = pcall( unpack( task ) )
            if not success then
                print( string.format( "Error running asynchronous task: %s", err ) )
            end
        end
    end
end