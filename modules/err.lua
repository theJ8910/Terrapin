--ComputerCraft overrides Lua's default error handling (likely because CC removes the debug library, which makes it impossible to get a stack trace).
--This is troublesome for a few reasons. All arguments to error() are converted to string, so tables cannot be thrown, for example.
--Additionally, every time an error is generated, ComputerCraft attaches the file and line to the error message.
--This includes when you only intended to rethrow the error, so the rethrow locations wind up cluttering the resulting error message.
--A series of functions are provided here to override CC's error handling with our own to make it function like Lua's original error handling.

--Some magic constants we use to detect whether our error2(), rethrow(), or olderror() was called
local ERROR_MSG         = "theJ89_ERROR"
local ERROR_RETHROW_MSG = "theJ89_ERROR_RETHROW"

--Counts how deep into pcall recursion we are
local pcallCounter = 0

--Forward declarations for pcall/xpcall/error overrides
local pcall2, xpcall2, error2

--Keep track of ComputerCraft's original pcall/xpcall/error functions
local oldpcall, oldxpcall, olderror

--Keep track of the file, line, and exact message of the last error that was thrown
local lastErr, lastFile, lastLine

--Anticipate an error being thrown.
--Calling this temporarily overrides pcall, xpcall, and error with pcall2, xpcall2, and error2 respectively.
--It will automatically reset to the original functions after a call to pcall2 or xpcall2 completes.
--NOTE: anticipateError() can't change a call to oldpcall/oldxpcall() on the stack into pcall2()/xpcall2().
--Only a call to pcall / xpcall that occurs /after/ anticipateError() has been called will work!
--This means that, for example, the following wouldn't work:
--    err.anticipate()
--    error( "Don't show the file and line number!" )
--because ComputerCraft has called oldpcall() to run our script; any errors it generates are handed to oldpcall().
function anticipate()
    if _G.pcall == pcall2 then return end

    oldpcall  = _G.pcall
    oldxpcall = _G.xpcall
    olderror  = _G.error
    _G.pcall  = pcall2
    _G.xpcall = xpcall2
    _G.error  = error2
end

--Return error handling back to what it was.
--You shouldn't need to call this unless you call anticipate() without calling pcall/xpcall afterwards.
function reset()
    if _G.pcall ~= pcall2 then return end

    _G.pcall  = oldpcall
    _G.xpcall = oldxpcall
    _G.error  = olderror
end

--Rethrows an error
function rethrow()
    olderror( ERROR_RETHROW_MSG )
end

--Returns the message, file, and line number of the last error that occurred.
--Returns nil, nil, nil if an error has not occurred since getLastError() was called.
--Note: anticipate() must be called prior to an error occurring, or this function will always return nil, nil, nil.
function getInfo()
    local err, file, line = lastErr, lastFile, lastLine
    lastErr, lastFile, lastLine = nil, nil, nil

    return err, file, line
end

--Parses msg for the file, line, and error message.
--Determines whether error2(), rethrow(), or olderror() was called and sets lastFile, lastLine, and lastErr appropriately.
local function record( msg )
    local line, file, msg = string.match( msg, "^(.-):(%d-): (.*)$", )

    --error2() was called
    if msg == ERROR_MSG then
        lastFile = file
        lastLine = line
    --rethrow() wasn't called; therefore olderror() was called
    --This can happen for various reasons; e.g. something called loadfile( "f.lua" ), and there was a syntax error in f.lua.
    elseif msg ~= ERROR_RETHROW_MSG then
        lastFile = file
        lastLine = line
        lastErr  = msg
    end
end

--pcall() override
pcall2 = function( ... )
    --pcall2/xpcall2 can be called recursively; keep track of how deep into pcall recursion we are
    pcallCounter = pcallCounter + 1
    local results = { oldpcall( ... ) }
    pcallCounter = pcallCounter - 1

    --If we've exited our final pcall, reset pcall/xpcall/error to their original functions
    if pcallCounter == 0 then reset() end

    --An error occurred...
    if not results[1] then
        record( results[2] )
        return false, lastErr
    end

    --No error
    return unpack( results )
end

--xpcall() override
xpcall2 = function( f, h )
    --Wrap the given handler so we can record error details
    local function h2( msg )
        record( msg )
        return h( lastErr )
    end

    --pcall2/xpcall2 can be called recursively; keep track of how deep into pcall recursion we are
    pcallCounter = pcallCounter + 1
    local results = { oldxpcall( f, h2 ) }
    pcallCounter = pcallCounter - 1

    --If we've exited our final pcall, reset pcall/xpcall/error to their original functions
    if pcallCounter == 0 then reset() end
    
    --Return whatever oldxpcall returns
    return unpack( results )
end

--error() override
error2 = function( err, level )
    if level == nil then level = 1 end

    --Record original error message
    lastErr = err

    --Let olderror() tell us where the error occurred
    --Note: the + 1 to the level here is necessary because level 1 would be error2(), level 2 would be whatever called error2(), etc.
    olderror( ERROR_MSG, level + 1 )
end