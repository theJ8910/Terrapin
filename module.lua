local env = getfenv()

--Make _G refer to this function's environment
local oldG = _G
env["_G"] = env
local gmt = { ["__index"] = env }

local modules = {}
function require( module, reload )
    if modules[module] ~= nil and not reload then
        return
    end
    
    --Load the file into a function
    local f, err = loadfile( module..".lua" )
    if f == nil then error( string.format( "Error loading \"%s.lua\": %s", module, err ) ) end
    
    --Give the loaded file its own 'global' table.
    --By default we allow access to the instance's global table through it
    --Anything the file declared globally will be in this table after the loaded script runs
    local t = {}
    myTable = t
    setmetatable( t, gmt )
    setfenv( f, t )
    
    modules[module] = t
    env[module] = t
    
    --Execute the file.
    local success, err = pcall( f )
    
    --Clear the table's metatable so it no longer has access to the instance's global table (bad idea?)
    --setmetatable( t, nil )
    
    --Unregister the modules if they failed to load.
    if not success then
        modules[ module ] = nil
        env[ module ] = nil
        error( string.format( "Error loading \"%s.lua\": %s", module, err ) )
    end
end