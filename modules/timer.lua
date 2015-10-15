local callbacks = {} --CC timer id -> function
local extIDs    = {} --CC timer id -> external ID
local intIDs    = {} --external ID -> CC timer ID

--Runs callback after delay seconds have passed (actual time may be longer than what was specified).
--Returns a timer ID. you can use this with timer.cancel (NOT os.cancelTimer) to cancel the timer.
function start( delay, callback )
    local intID = os.startTimer( delay, callback )
    local extID = #intIDs
    callbacks[ intID ] = callback
    extIDs[ intID ]    = extID
    intIDs[ extID ]    = intID

    return extID
end

--Same as start, but repeats the timer.
--NOTE: I'd rather call this "repeat", but that's a reserved keyword in Lua.
function repeating( delay, callback )
    --NOTE: We have to forward declare f here because f references itself.
    --If we tried to do "local function f() ... end", f wouldn't see itself
    --because f becomes a local AFTER the function is defined...
    --Same kind of deal with "t" here (our timer object). We need to update the ID
    --every time the timer repeats, but the t doesn't exist until we create it below.
    local extID
    local f
    f = function()
        --Reserve this ID just in case the callback creates a timer
        intIDs[ extID ] = -1
        
        --Call the callback, allowing any errors that may occur to propagate.
        --We have to pcall the callback so that we can free up the external ID if it fails.
        local success, err = pcall( callback )
        if not success then
            intIDs[ extID ] = nil
            return error( err )
        end

        --Restart the timer; make sure it uses the same external ID
        local intID = os.startTimer( delay, f )
        callbacks[ intID ] = f
        extIDs[ intID ] = extID
        intIDs[ extID ] = intID
    end

    --Start the timer for the first time
    local intID = os.startTimer( delay, f )
          extID = #intIDs
    callbacks[ intID ]  = f
    extIDs[ intID ]     = extID
    intIDs[ extID ]     = intID

    return extID
end

--Cancels the timer with the given external ID.
function cancel( extID )
    local intID = intIDs[ extID ]
    if intID == nil then return end

    os.cancelTimer( intID )
    callbacks[ intID ] = nil
    extIDs[ intID ] = nil
    intIDs[ extID ] = nil
end

--Your application should call this in your event loop to handle a timer event.
--false is returned if we couldn't find the timer with the given internal ID (this usually means it was started by something other than timer.lua).
--Otherwise, true is returned.
--Any errors that occur when running the function associated with the timer are allowed to propagate.
function handle( intID )
    local fn = callbacks[ intID ]
    
    if fn ~= nil then
        --Remove timer
        local extID = extIDs[ intID ]
        callbacks[ intID ] = nil
        extIDs[ intID ] = nil
        intIDs[ extID ] = nil

        --Call the callback
        fn()
        return true
    end
    return false
end