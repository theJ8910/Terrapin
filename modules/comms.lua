require( "enums" )
require( "vector" )
require( "worker" )
require( "util" )

local myID
local modem
local modemSide

--These values influence the wireless range between two computers.
--These settings are dependent upon ComputerCraft's configuration and the settings / current state of the world; I've entered the defaults below.
--A lot of these values could probably be determined experimentally by turtles, but the user will probably end up entering these manually.
--A rain sensor and daylight sensor could be used to detect if there is a storm or not. This could work for the mainframe, but if the bots would
--have no way of knowing if it was raining or not, unless they had rain sensors of their own or were close enough to receive
--weather updates from the mainframe.
local minTransmitDistance      = 64
local maxTransmitDistance      = 384
local minTransmitDistanceStorm = 16
local maxTransmitDistanceStorm = 96
local worldHeight              = 256
local isStorming               = false

function __init()
    myID = os.getComputerID()
end

--Should be called when a modem is attached
function onModemAttached( side )
    if modem == nil then
        print( string.format( "Modem attached on side %s", side ) )

        modem = peripheral.wrap( side )
        modemSide = side

        --Listen on our channel and broadcast channel
        modem.open( myID )
        modem.open( 65535 )
    end
end

--Should be called when a modem is removed
function onModemDetached( side )
    if modem ~= nil and side == modemSide then
        print( string.format( "Modem removed on side %s", side ) )

        modem     = nil
        modemSide = nil
    end
end

--Sends a message to the given channel
local packetCount = 0
function transmit( chOut, msgId, ... )
    packetCount = packetCount + 1
    modem.transmit( chOut, myID, {
        ["c"] = msgId,
        ["i"] = packetCount,
        ...
    } )
end

local handlers = {
    [ enums.ANNOUNCE ] = function( side, chIn, chOut, message, distance )
        print( string.format( "Sending handshake to turtle %d.", chOut ) )
        transmit( chOut, enums.HANDSHAKE )
    end,
    [ enums.ACCEPT    ] = function( side, chIn, chOut, message, distance )
        print( string.format( "Turtle %d accepted handshake.", chOut ) )
        worker.add( chOut )
    end,
    [ enums.REJECT    ] = function( side, chIn, chOut, message, distance )
        print( string.format( "Turtle %d rejected handshake.", chOut ) )
    end,
    [ enums.OK        ] = function( side, chIn, chOut, message, distance )
        print( string.format( "Turtle %d replies: %d OK: %s", chOut, message.i, util.join( message ) ) )
    end,
    [ enums.ERR       ] = function( side, chIn, chOut, message, distance )
        print( string.format( "Turtle %d replies: %d ERR: %s", chOut, tostring( message[1] ) ) )
    end,
}

--Handles an incoming message
function handle( side, chIn, chOut, message, distance )
    print( string.format( "Side: %s Receiving Ch: %s Reply Ch: %s Message: %s Distance: %f", side, chIn, chOut, tostring( message ), distance ) )
    print( string.format( "Reception is %f%%.", util.round( 1000 * signalStrength( distance ) ) / 10 ) )

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

    --No problems
    return true
end

--Returns a fraction between 0 and 1 indicating how good the reception is between the transmitter is to the receiver.
--The position of both the transmitter and receiver must be known. So long as these positions are accurate, this function is 100% accurate.
--If this returns 0, the transmitter is at or beyond that maximum range that the receiver can be communicated with.
--If this returns 1, the transmitter and receiver are at the same position.
function signalStrengthBothKnown( transmitterPos, receiverPos )
    local distance = vector.distance( transmitterPos, receiverPos )

    --The maximum range these two devices can communicate with one another.
    --ComputerCraft determines this by calculating the transmit range for both the transmitter and receiver and taking the larger of the two.
    local range = math.max(
        getTransmitRange( transmitterPos.y ),
        getTransmitRange( receiverPos.y )
    )

    --Note: Both distance and range are positive, so dividing the two can't result in a negative number.
    --Distance can be larger than range though, so we have to ensure the fraction doesn't exceed 1.
    return 1 - math.min( 1, distance / range )
end

--Same as signalStrengthBothKnown, but doesn't require prior knowledge of only one position (the receiver or the transmitter). 
--As a result, the calculation may be less precise. Without knowing the exact location of the receiver we must assume that the position of the given device has the greater range.
--The receiver could very well have a greater range if it is located above the transmitter; e.g. transmitter at bedrock, receiver in the sky.
--So long as the transmitter is at or above the receiver, this function is 100% accurate. Otherwise, it will underestimate the signal strength.
function signalStrengthOneUnknown( knownPos, distance )
    return 1 - math.min( 1, distance / getTransmitRange( knownPos.y ) )
end

--Same as signalStrengthBothKnown, but doesn't require prior knowledge of the transmitter nor the receivers' positions.
--Without knowing these locations, we must assume the transmit range is the minimum.
--So long as both the receiver and the transmitter are at or below y = 96, this function is 100% accurate.
--Otherwise, it will underestimate the signal strength.
function signalStrengthBothUnknown( distance )
    return 1 - math.min( 1, distance / ( isStorming and minTransmitDistanceStorm or minTransmitDistance ) )
end

--Given the distance, and optionally transmitterPos and/or receiverPos, calls the appropriate signalStrength* function above.
function signalStrength( distance, transmitterPos, receiverPos )
    if transmitterPos ~= nil then
        if receiverPos ~= nil then  return signalStrengthBothKnown( transmitterPos, receiverPos )
        else                        return signalStrengthOneUnknown( receiverPos, distance )
        end
    elseif receiverPos ~= nil then  return signalStrengthOneUnknown( receiverPos, distance )
    else                            return signalStrengthBothUnknown( distance )
    end
end

--Calculates the minimum range for a transmitter at the given altitude.
function getTransmitRange( altitude )
    local min, max
    if isStorming then
        min = minTransmitDistanceStorm
        max = maxTransmitDistanceStorm
    else
        min = minTransmitDistance
        max = maxTransmitDistance
    end

    --If transmitter is at or above 96 meters, calculate range bonus due to altitude
    --Note: maximum altitude is worldHeight - 1
    if altitude > 96 and min < max then
        return min + ( max - min ) * ( altitude - 96 ) / ( worldHeight - 97 )
    end

    return min
end