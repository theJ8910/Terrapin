if turtle == nil then return error( "This module can only be used by a turtle." ) end
require( "enums" )
require( "turtle2.item" )
require( "device" )
require( "async" )

local myID
local mainframeID = nil

local modem
local modemSide

local sensor
local sensorSide





--In-memory storage for programs sent to us
--Maps key => function
local programs = {}

--Transmit a message
local function transmit( chOut, message )
    if modem == nil then return false end
    modem.transmit( chOut, myID, message )
    return true
end

local announceTimer
local function announce()
    print( "Searching for mainframe to connect to..." )
    transmit( 65535, { ["c"] = enums.ANNOUNCE } )

    --Reannounce after 5 sec
    announceTimer = os.startTimer( 5 )
end



--Calls fn, passing any additional arguments given to this function to fn.
--If fn completes successfully, transmits an OK message to chOut containing whatever the function returns.
--If fn encounters an error, transmits an ERR message to chOut containing the error message.
--Note: fn may return as many values as necessary, but the return values must be nil, string, number, boolean, or table.
--Functions, threads, and userdata should not be returned. Returned tables should not contain these datatypes either.
local function runAndReply( chOut, packetID, fn, ... )
    local results = { pcall( fn, ... ) }
    if results[1] then transmit( chOut, { ["c"] = enums.OK,  ["i"] = packetID, select( 2, unpack( results ) ) } )
    else               transmit( chOut, { ["c"] = enums.ERR, ["i"] = packetID, [1] = results[2] } )
    end
end

--Returns a message handler that calls runAndReply asynchronously,
--passing chOut as the first argument, fn as the second, and any additional arguments provided to the returned handler as additional arguments to runAndReply.
--See runAndReply for more information.
local function makeAsyncReplyHandler( fn )
    return function( side, chIn, chOut, message, distance )
        async.runLater( runAndReply, chOut, message.i, fn, unpack( message ) )
    end
end

local function onItemAdded( slot, item )
    --A wireless modem isn't equipped, but we've found one
    if modem == nil and item.name == "ComputerCraft:CC-Peripheral" and item.damage == 1 then
        turtle.select( slot )

        local side = device.equip( "left" )
        if side == nil then print( "Can't equip modem." ); return end
    end
end

local function onDeviceAdded( side, t )
    if modem == nil and t == "modem" then
        --Must be a wireless modem
        local m = peripheral.wrap( side )
        if not m:isWireless() then return end

        print( string.format( "Found modem on %s side.", side ) )
        modem     = m
        modemSide = side

        --Open modem, announce that turtle is now online
        modem.open( myID )
        announce()

    --OpenPeripheral sensor
    elseif sensor == nil and t == "turtlesensorenvironment" then
        local s = peripheral.wrap( side )

        print( string.format( "Found sensor on %s side.", side ) )
        sensor     = s
        sensorSide = side
    end
end

local function onDeviceRemoved( side, t )
    if t == "modem" and side == modemSide then
        modem     = nil
        modemSide = nil
    elseif t == "turtlesensorenvironment" then
        sensor     = nil
        sensorSide = nil
    end
end

local function onDeviceRewrap( side, t )
    if t == "modem" and side == modemSide then
        modem = peripheral.wrap( side )
    end
end

--Message handlers
local handlers = {
    [ enums.HANDSHAKE         ] = function( side, chIn, chOut, message, distance )
        if mainframeID ~= nil then
            transmit( chOut, { ["c"] = enums.REJECT, ["i"] = message.i } )
        else
            mainframeID = chOut
            transmit( chOut, { ["c"] = enums.ACCEPT, ["i"] = message.i } )
            print( string.format( "Connected to mainframe %d.", chOut ) )

            if announceTimer ~= nil then
                os.cancelTimer( announceTimer )
                announceTimer = nil
            end
        end
    end,
    [ enums.MOVE_FORWARD      ] = makeAsyncReplyHandler( turtle.forward         ),
    [ enums.MOVE_BACK         ] = makeAsyncReplyHandler( turtle.back            ),
    [ enums.MOVE_UP           ] = makeAsyncReplyHandler( turtle.up              ),
    [ enums.MOVE_DOWN         ] = makeAsyncReplyHandler( turtle.down            ),
    [ enums.TURN_LEFT         ] = makeAsyncReplyHandler( turtle.turnLeft        ),
    [ enums.TURN_RIGHT        ] = makeAsyncReplyHandler( turtle.turnRight       ),

    [ enums.ATTACK            ] = makeAsyncReplyHandler( turtle.attack          ),
    [ enums.ATTACK_UP         ] = makeAsyncReplyHandler( turtle.attackUp        ),
    [ enums.ATTACK_DOWN       ] = makeAsyncReplyHandler( turtle.attackDown      ),

    [ enums.DIG               ] = makeAsyncReplyHandler( turtle.dig             ),
    [ enums.DIG_UP            ] = makeAsyncReplyHandler( turtle.digUp           ),
    [ enums.DIG_DOWN          ] = makeAsyncReplyHandler( turtle.digDown         ),
    [ enums.PLACE             ] = makeAsyncReplyHandler( turtle.place           ),
    [ enums.PLACE_UP          ] = makeAsyncReplyHandler( turtle.placeUp         ),
    [ enums.PLACE_DOWN        ] = makeAsyncReplyHandler( turtle.placeDown       ),

    [ enums.DETECT            ] = makeAsyncReplyHandler( turtle.detect          ),
    [ enums.DETECT_UP         ] = makeAsyncReplyHandler( turtle.detectUp        ),
    [ enums.DETECT_DOWN       ] = makeAsyncReplyHandler( turtle.detectDown      ),
    [ enums.COMPARE           ] = makeAsyncReplyHandler( turtle.compare         ),
    [ enums.COMPARE_UP        ] = makeAsyncReplyHandler( turtle.compareUp       ),
    [ enums.COMPARE_DOWN      ] = makeAsyncReplyHandler( turtle.compareDown     ),
    [ enums.INSPECT           ] = makeAsyncReplyHandler( turtle.inspect         ),
    [ enums.INSPECT_UP        ] = makeAsyncReplyHandler( turtle.inspectUp       ),
    [ enums.INSPECT_DOWN      ] = makeAsyncReplyHandler( turtle.inspectDown     ),

    [ enums.DROP              ] = makeAsyncReplyHandler( turtle.drop            ),
    [ enums.DROP_UP           ] = makeAsyncReplyHandler( turtle.dropUp          ),
    [ enums.DROP_DOWN         ] = makeAsyncReplyHandler( turtle.dropDown        ),
    [ enums.SUCK              ] = makeAsyncReplyHandler( turtle.suck            ),
    [ enums.SUCK_UP           ] = makeAsyncReplyHandler( turtle.suckUp          ),
    [ enums.SUCK_DOWN         ] = makeAsyncReplyHandler( turtle.suckDown        ),

    [ enums.ITEM_SELECT       ] = makeAsyncReplyHandler( turtle.select          ),
    [ enums.ITEM_GET_SELECTED ] = makeAsyncReplyHandler( turtle.getSelectedSlot ),
    [ enums.ITEM_COUNT        ] = makeAsyncReplyHandler( turtle.getItemCount    ),
    [ enums.ITEM_FREE         ] = makeAsyncReplyHandler( turtle.getItemSpace    ),
    [ enums.ITEM_DETAILS      ] = makeAsyncReplyHandler( turtle.getItemDetail   ),
    [ enums.ITEM_MOVE         ] = makeAsyncReplyHandler( turtle.transferTo      ),

    [ enums.EQUIP_LEFT        ] = makeAsyncReplyHandler( function()
        --Disallow replacing the modem
        if modemSide == "left"    then return false end
        if not turtle.equipLeft() then return false end
        device.update( "left" )
        return true
    end ),
    [ enums.EQUIP_RIGHT       ] = makeAsyncReplyHandler( function()
        --Disallow replacing the modem
        if modemSide == "right"    then return false end
        if not turtle.equipRight() then return false end
        device.update( "right" )
        return true
    end ),

    [ enums.PER_ISPRESENT     ] = makeAsyncReplyHandler( peripheral.isPresent   ),
    [ enums.PER_TYPE          ] = makeAsyncReplyHandler( peripheral.getType     ),

    [ enums.REFUEL            ] = makeAsyncReplyHandler( turtle.refuel          ),
    [ enums.FUEL_LEVEL        ] = makeAsyncReplyHandler( turtle.getFuelLevel    ),
    [ enums.FUEL_LIMIT        ] = makeAsyncReplyHandler( turtle.getFuelLimit    ),

    [ enums.FS_WRITE          ] = makeAsyncReplyHandler( function( path, contents )
        local file = fs.open( path, "w" )
        if file == nil then return false end
        file.write( contents )
        file.close()
        return true
    end ),
    [ enums.FS_READ           ] = makeAsyncReplyHandler( function( path )
        local file = fs.open( path, "r" )
        if file == nil then return false end
        local contents = file.readAll()
        file.close()
        return contents
    end ),
    [ enums.FS_MKDIR          ] = makeAsyncReplyHandler( fs.makeDir             ),
    [ enums.FS_DELETE         ] = makeAsyncReplyHandler( fs.delete              ),
    [ enums.FS_COPY           ] = makeAsyncReplyHandler( fs.copy                ),
    [ enums.FS_MOVE           ] = makeAsyncReplyHandler( fs.move                ),
    [ enums.FS_LIST           ] = makeAsyncReplyHandler( fs.list                ),
    [ enums.FS_EXISTS         ] = makeAsyncReplyHandler( fs.exists              ),
    [ enums.FS_IS_DIR         ] = makeAsyncReplyHandler( fs.isDir               ),

    [ enums.SHUTDOWN          ] = makeAsyncReplyHandler( function()
        --TODO: cleanup hook
        os.shutdown()
    end ),
    [ enums.REBOOT            ] = makeAsyncReplyHandler( function()
        --TODO: cleanup hook
        os.reboot()
    end ),

    [ enums.PROGRAM_ADD          ] = makeAsyncReplyHandler( function( name, contents )
        local f = loadstring( contents, name )
        programs[ name ] = f
    end ),
    [ enums.PROGRAM_REMOVE       ] = makeAsyncReplyHandler( function( name )
        programs[ name ] = nil
    end ),
    [ enums.PROGRAM_RUN          ] = makeAsyncReplyHandler( function( name )
        programs[ name ]()
    end ),

    [ enums.CRAFT                ] = makeAsyncReplyHandler( turtle.craft        ),

    [ enums.OPENP_SONIC_SCAN     ] = makeAsyncReplyHandler( function()
        if sensor == nil then return nil end

        return sensor.sonicScan()
    end ),
    [ enums.OPENP_PLAYERS        ] = makeAsyncReplyHandler( function()
        if sensor == nil then return nil end

        return sensor.getPlayerNames()
    end ),
    [ enums.OPENP_MINECART_IDS   ] = makeAsyncReplyHandler( function()
        if sensor == nil then return nil end

        return sensor.getMinecartIDs()
    end ),
    [ enums.OPENP_MOB_IDS        ] = makeAsyncReplyHandler( function()
        if sensor == nil then return nil end

        return sensor.getMobIDs()
    end ),
    [ enums.OPENP_ENTITY_IDS     ] = makeAsyncReplyHandler( function( t )
        if sensor == nil then return nil end

        return sensor.getEntityIDs( t )
    end ),
    --NOTE: The open peripheral sensor "data" functions return tables with functions... fix that.
    [ enums.OPENP_PLAYER_BY_NAME ] = makeAsyncReplyHandler( function( name )
        if sensor == nil then return nil end

        return nil
        --return sensor.getPlayerByName( name )
    end ),
    [ enums.OPENP_PLAYER_BY_UUID ] = makeAsyncReplyHandler( function( uuid )
        if sensor == nil then return nil end

        return nil
        --return sensor.getPlayerByUUID( uuid )
    end ),
    [ enums.OPENP_MINECART_DATA  ] = makeAsyncReplyHandler( function( id )
        if sensor == nil then return nil end

        return nil
        --return sensor.getMinecartData( id )
    end ),
    [ enums.OPENP_MOB_DATA       ] = makeAsyncReplyHandler( function( id )
        if sensor == nil then return nil end

        return nil
        --return sensor.getMobData( id )
    end ),
    [ enums.OPENP_ENTITY_DATA    ] = makeAsyncReplyHandler( function( id, t )
        if sensor == nil then return nil end

        return nil
        --return sensor.getEntityData( id, t )
    end ),
    --[ enums. ] = ,
}

--Handle a received message.
--Returns true if the message was handled, false otherwise.
local function handleMessage( side, chIn, chOut, message, distance )
    --The message must be in a format we understand
    if type( message ) ~= "table" or type( message.c ) ~= "number" then
        print( "Received an unrecognized message." )
        return false
    end

    --Find handler for this message; fail if message not recognized
    local msgID = message.c
    local handler = handlers[ msgID ]
    if handler == nil then
        print( string.format( "Unrecognized message with ID %d.", msgID ) )
        return false
    end

    --Call the handler; fail if an error occurs
    local success, err = pcall( handler, side, chIn, chOut, message, distance )
    if not success then
        print( string.format( "Error handling message ID %d: %s", msgID, err ) )
        return false
    end

    return true
end

--Event processing loop
local function eventProc()
    while true do
        local event, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()

        --Message received on a modem.
        --string side, number receiving channel, number reply channel, any message, number distance
        if event == "modem_message" then
            handleMessage( arg1, arg2, arg3, arg4, arg5 )
        --Turtle inventory changed (for any reason. e.g. player activity, the turtle itself placing / picking up blocks, etc).
        --No arguments
        elseif event == "turtle_inventory" then
            item.scan()
        --Peripheral attached / detached.
        --string side
        elseif event == "peripheral" or event == "peripheral_detach" then
            device.update( arg1 )
        --TEMP: timer
        --number id
        elseif event == "timer" then
            if arg1 == announceTimer then announce() end
        --number scancode, boolean is_held
        elseif event == "key" then
            --Q exits the program (I'd make it escape, but that's the key ComputerCraft uses to leave its GUI)
            if arg1 == 16 then return end
        end
    end
end

function __init()
    myID = os.getComputerID()
end

function __main()
    item.addListener( "added", onItemAdded )
    device.addListener( "added", onDeviceAdded )
    device.addListener( "removed", onDeviceRemoved )
    device.addListener( "rewrap", onDeviceRewrap )

    --Take inventory of attached items and peripherals.
    device.scan()
    item.scan()

    --Turtles are mostly dumb terminals.
    --They're not responsible for doing anything too complicated; a connected mainframe is responsible for this.
    --But with no modem, this is a little difficult to do.
    if modem == nil then
        print( "No modem found! Put one in my inventory." )
    end

    parallel.waitForAny( eventProc, async.taskProc )
end

function __cleanup()
    item.removeListener( "added", onItemAdded )
    device.removeListener( "added", onDeviceAdded )
    device.removeListener( "removed", onDeviceRemoved )
    device.removeListener( "rewrap", onDeviceRewrap )
end