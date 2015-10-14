--TODO:
--Currently, some modules (e.g. class.lua) register globals (e.g. "new").
--  Should I allow this or bring class.lua into this whole framework I'm building here?
--Reloading modules
--  This should be possible, but it's probably not going to be as simple as rebuilding the import table (because of the ability to import keys by themselves).
--  Besides that, modules can hang onto references that are out of date depending on how they're coded... waste time solving this?
local env = getfenv()

--Load some privileged modules manually
--TEMP: loading "class" module like this
local paths = {}
class = {}
do
    local mmt = { __index = env }
    local function manual_load( t, file )
        t._G = env
        setmetatable( t, mmt )
        local f = loadfile( fs.combine( shell.dir() , file ) )
        setfenv( f, t )
        f()
    end

    manual_load( paths, "paths.lua" )
    manual_load( class, "class.lua" )
end

--Module states
local STATE_NOT_LOADED   = 0 --Module's file hasn't been loaded (or has been unloaded)
local STATE_LOADING      = 1 --Module's file hasn't been executed yet
local STATE_LOADED       = 2 --Module is loaded, but hasn't been initialized
local STATE_INITIALIZING = 3 --Module is loaded and is in the process of being initialized
local STATE_INITIALIZED  = 4 --Module is loaded and has been successfully initialized
local STATE_UNLOADING    = 5 --Module is being unloaded

--A simple way to determine whether the host machine is Windows or Unix based.
--This matters because we record what modules are loaded by filepath.
--Because filepaths on Windows are case insensitive, two filepaths differing by case can refer to the same file.
--On Unix-based systems however, those same two filepaths refer to different files, so the distinction is important.
local isWindows
do
    local p = shell.getRunningProgram()
    isWindows = fs.exists( p ) and fs.exists( string.upper( p ) )
end

--The module we're instructed to run.
local main_module = nil

--Collection of registered modules.
--Maps key -> module.
local modules = {}

--Stack of modules in the process of being loaded.
--Used to determine dependencies between modules.
local loading_modules = {}

--Search paths for modules. These should all be absolute paths.
local searchpaths = {
    paths.get( "/modules" )
}

--Given an absolute path to a module (in string form), returns a key for the module.
--The key is used to look up a module in the the modules table.
local module_key
if isWindows then
    module_key = function( path )
        return string.lower( path )
    end
else
    module_key = function( path )
        return path
    end
end

local mnfn = {}
local mnmt = {}

--Given a module name as a string, validates the name and returns a parsed module name.
--A module name is valid if each of its parts (separated by ".") follow these rules:
--    1. Parts cannot not be empty
--    2. Parts cannot start with digits
--    3. Parts can contain only alphanumeric characters and underscores
--"a.b.c" -> { "a", "b", "c" }
local function parseModuleName( str )
    if str == "" then error( "A module name cannot be empty!" ) end
    local name = {}
    setmetatable( name, mnmt )
    
    local len = #str
    local i = 1
    while i <= len do
        local d = string.find( str, "%.", i ) or ( len + 1 )
        local part = string.sub( str, i, d - 1 )
        if     part == ""                    then return error( string.format( "\"%s\" is an invalid module name. It contains empty parts.", str ), 3 )
        elseif string.find( part, "^%d" )    then return error( string.format( "\"%s\" is an invalid module name. \"%s\" starts with digits.", str, part ), 3 )
        elseif string.find( part, "[^%w_]" ) then return error( string.format( "\"%s\" is an invalid module name. \"%s\" contains one or more non-alphanumeric, non-underscore characters.", str, part ), 3 )
        end
        table.insert( name, part )
        i = d + 1
    end

    return name
end

--{ "a", "b", "c" } -> paths.get( "a/b/c.lua" )
function mnfn:toPath()
    local path = paths.get( "" )
    local c = #self
    for i = 1, c - 1 do
        path:append( self[ i ] )
    end
    path:append( self[ c ]..".lua" )

    return path
end

--{ "a", "b", "c" } -> "a.b.c"
function mnfn:toString()
    local name = self[1]
    for i = 2, #self do
        name = name..self[i]
    end
    return name
end

mnmt.__index    = mnfn
mnmt.__tostring = mnfn.toString




--Given a path and the current working directory, returns a path for the module.
--path and cwd are both expected to be path objects, and cwd must be absolute.
--Returns or nil if the module couldn't be found.
local function findModule( path, cwd )
    --If the path exists, returns it. Otherwise, returns nil.
    local f = function( path )
        if path:exists() then return path end
        return nil
    end

    --Check the exact path we were given.
    if     path.type == paths.TYPE_ABSOLUTE then
        return f( path )
    --Check a path relative to the current working directory.
    elseif path.type == paths.TYPE_RELATIVE then
        return f( cwd..path )
    --Check paths relative to one or more search paths.
    elseif path.type == paths.TYPE_SEARCHPATH then
        local path2

        --Search the current directory first
        path2 = f( cwd..path )
        if path2 ~= nil then return path2 end

        --Search dirs in first-to-last order
        for i,v in ipairs( searchpaths ) do
            path2 = f( v..path )
            if path2 ~= nil then return path2 end
        end
    end
    return nil
end

--Records dependent as requiring dependency.
local function addDependency( dependent, dependency )
    if dependent.dependencies[ dependency ] ~= nil then return end

    dependent.dependencies[ dependency ] = true
    dependency.dependents[ dependent ]   = true

    dependency.dependentCount = dependency.dependentCount + 1
end

--Records dependent as no longer requiring dependency.
local function removeDependency( dependent, dependency )
    if dependent.dependencies[ dependency ] == nil then return end

    dependent.dependencies[ dependency ] = nil
    dependency.dependents[ dependent ]   = nil

    dependency.dependentCount = dependency.dependentCount - 1
end

--Unloads the given module.
local function unloadModule( module )
    --Module's already in the process of being unloaded; nothing to do
    if module.state == STATE_UNLOADING then return end
    local wasInitialized = ( module.state == STATE_INITIALIZED )
    module.state = STATE_UNLOADING
    
    --Unload modules that depend on this module first
    local k = next( module.dependents )
    while k ~= nil do
        --Calling this removes k from module.dependents
        unloadModule( k )
        k = next( module.dependents )
    end

    --If the module was initialized, call the module's cleanup function (if it has one)
    if wasInitialized then
        local cleanup = module.t.__cleanup
        if cleanup ~= nil then
            local success, err = pcall( cleanup )
            if not success then
                print( string.format( "Error cleaning up module \"%s\": %s", tostring( module.path ), err ) )
            end
        end
    end

    --Unregister the module
    modules[ module.key ] = nil
    if module == main_module then main_module = nil end
    module.state = STATE_NOT_LOADED

    --Modules that we depend on should no longer record us as dependents
    local k = next( module.dependencies )
    while k ~= nil do
        --Calling this removes k from module.dependencies
        removeDependency( module, k )

        --Automatically unload k if module was its last dependent.
        if k.dependentCount == 0 and k ~= main_module then unloadModule( k ) end

        k = next( module.dependencies )
    end
end

--Returns the module with the given path if it is already loaded,
--or attempts to search for the module and load it.
local function getModule( name, cwd )
    --Locate the module with this path
    local path = findModule( name:toPath(), cwd )
    if path == nil then return error( string.format( "Couldn't find module \"%s\".", tostring( name ) ), 3 ) end

    --Find the module, or attempt load it if it's not loaded yet
    local pathstr = path:toString()
    local key = module_key( pathstr )
    local m   = modules[ key ]
    if m == nil then
        --ComputerCraft's operating system and the programs you run on it share the same Lua instance.
        --Modules are intended to be self-contained; some care must be taken to isolate loaded modules so that
        --they do not pollute the environment of the shell that launched the program, nor the global table _G.
        --Below is a simple sandbox that will help us achieve this goal.
        --Globals that this module creates will be placed in "ut". When another module require()s this module, it will have access to anything in this table.
        --Anything that the module require()s will be placed in "it". Only this module can access the contents of this table.
        --When a module looks for a global, it will check "ut" first, followed by "it",
        --and then finally env (module.lua's environment, which has access to globals such as Lua builtins, Computercraft APIs, require(), etc).
        local ut = {}
        local it = {}
        local mt = { __index = function( t, k ) return ut[k] or it[k] or env[k] end, __newindex = ut }
        local t  = {}

        --_G is the globals table; make the module think its own environment is the globals table.
        it._G = t
        setmetatable( t, mt )
        m = {
            [ "key"            ] = key,              --The key the module is stored under in our modules collection.
            [ "path"           ] = path,             --Path object to the .lua file for the module
            [ "t"              ] = ut,               --Module's unique table.
            [ "it"             ] = it,               --Module's import table.
            [ "dependencies"   ] = {},               --Modules that this module depends upon. This module will be unloaded if any of these modules are unloaded.
            [ "dependents"     ] = {},               --This module is depended upon by these modules.
            [ "dependentCount" ] = 0,                --Number of modules depending upon this module. A module is safe to unload when it has no dependents.
            [ "state"          ] = STATE_NOT_LOADED, --State the module is in
        }

        table.insert( loading_modules, m )
        local success, err = ( function()
            --Load the file into a function
            local f, err = loadfile( pathstr )
            if f == nil then return false, err end

            --Sandbox the loaded file.
            setfenv( f, t )

            --Register with the module loader
            modules[ key ] = m
            
            --Execute the file.
            m.state = STATE_LOADING
            local success, err = pcall( f )

            --Unload the modules if they failed to load.
            if not success then
                unloadModule( m )
                return false, err
            end

            --Module loaded successfully
            m.state = STATE_LOADED
            return true
        end )()
        
        table.remove( loading_modules )
        if not success then error( err, 3 ) end
    end
    return m
end

--Initializes the given module's dependencies recursively, then initializes the given module.
--While a module is being initialized, its state is set to STATE_INITIALIZING.
--After a module has been successfully initialized, its state is set to STATE_INITIALIZED.
local function initializeModule( module )
    --A module should only be initialized if it's in STATE_LOADED.
    --This prevents infinite recursion in the case of a circular dependency.
    if module.state ~= STATE_LOADED then return end
    module.state = STATE_INITIALIZING

    --Initialize modules we depend on first
    for k,v in pairs( module.dependencies ) do
        initializeModule( k )
    end

    --Call the module's __init function (if it has one).
    local init = module.t.__init
    if init ~= nil then init() end

    --If we make it to here, the module has been successfully initialized
    module.state = STATE_INITIALIZED
end

--Called by importFQN and importSimple.
local function importError( k, v )
    return error( string.format( "Import conflict: %s is already set to %s", tostring( k ), tostring( v ) ) )
end

--Sets t[ k ] = v if t[ k ] is nil.
--If t[ k ] is already v, does nothing.
--Otherwise, generates an error.
local function importSimple( t, k, v )
    if     t[ k ] == nil then t[ k ] = v
    elseif t[ k ] ~= v   then importError( k, t[k] )
    end
end

--Imports a module using its fully qualified name.
--Creates a chain of nested tables such that the following is achieved:
--    it.name_1.name_2. ... .name_n = ut
--Non-existing tables are created, and existing tables are reused.
--If a non-table key is encountered, an error is generated.
local function importFQN( it, ut, name )
    local c = #name
    local lastPart = name[ c ]

    local t = it
    for i = 1, c - 1 do
        local k = name[i]
        local v = t[ k ]
        if v == nil then
            v = {}
            t[ k ] = v
        elseif type( v ) ~= "table" then
            return importError( k, v )
        end
        t = v
    end

    importSimple( t, lastPart, ut )
end

--Handles importing one module into another
local function import( it, ut, name, importKeys )
    --Import the module under both its simple name and its fully qualified name
    importFQN( it, ut, name )
    importSimple( it, name[ #name ], ut )

    --Import any additional keys specified by the module
    for i,k in ipairs( importKeys ) do
        --Import all keys
        if k == "*" then
            for k2, v in pairs( ut ) do
                importSimple( it, k2, v )
            end
            return

        --Import specific keys
        else
            importSimple( it, k, ut[ k ] )
        end
    end
end

--Loads and runs the module with the given name and sets it as our main module.
--Returns whatever the __main() function of the given module returns if it loads and runs without error.
function run( name )
    if type( name ) ~= "string" then return error( "name is not a string.", 2 ) end

    --Grab the module we're looking for
    name = parseModuleName( name )
    main_module = getModule( name, paths.get( "/"..shell.dir() ) )

    --This bit of code is isolated in its own function to make error handling easier (it's a try block, basically).
    --This function returns "false" as its first value if an error occurs, or "true" if it doesn't.
    --main() can return many values, so we pack them into a results table.
    local results = { ( function()
        --Main module and all its dependencies have loaded; now we initialize the main module and its dependencies
        local success, err = pcall( initializeModule, main_module )
        if not success then return false, err end

        --Make sure the module has a .__main() function
        local main = main_module.t.__main
        if main == nil then
            return false, "No __main() function!"
        end

        --Call __main().
        return pcall( main )
    end )() }

    --Regardless of whether an error occurred or not, we unload the main module after the program finishes
    unloadModule( main_module )

    --The first result is always whether or not the call executed without error.
    --The second result will be an error message if it didn't.
    local success, err = results[1], results[2]
    if not success then
        return error( string.format( "Error running \"%s\": %s", tostring( name ), err ), 2 )
    end

    --If main() exited without error, results 2, 3, ... are returned by this function.
    return select( 2, unpack( results ) )
end

--Call this from one module to require another module.
--Example usage:
--    require( "myproject.mymodule" )
--
--After calling require(), the module can access its members by the required module's name:
--    print( mymodule.member )
--
--Or by its fully qualified name:
--    print( myproject.mymodule.member )
--
--Additionally, your module can import the contents of a module by specifying which keys in the module you want to import (or "*" to import all keys).
--This works similarly to the "using" statement in C++, or the "import" statement in Java:
--    require( "myproject.mymodule", "member" )
--    print( member )
function require( name, ... )
    if type( name ) ~= "string" then return error( "name is not a string.", 2 ) end

    --Determine what module is requiring us
    local dependent = loading_modules[ #loading_modules ]
    if dependent == nil then return error( "require() must be called from within a module", 2 ) end

    --Grab the module we're looking for
    name = parseModuleName( name )
    local dependency = getModule( name, dependent.path:getParent() )

    --Is this already a dependency? If so, we've got nothing more to do here.
    if dependent.dependencies[ dependency ] ~= nil then return end

    --Add the loaded module as a dependency of the module that requires it
    addDependency( dependent, dependency )

    --Now we create entries in the dependent module's import table.
    --Doing this allows the requiring module to use it.
    import( dependent.it, dependency.t, name, { ... } )
end

--If the name of a module is provided as an argument, run that module.
--e.g. "module.lua main.lua"
if select( "#", ... ) > 0 then
    run( ..., nil )
end