--Note: this module is called "device.lua" so that it doesn't conflict with the "peripheral" API

--Sides that peripherals can be directly attached to.
local sides = {
    "left", "right", "front", "back", "top", "bottom"
}



--Keep track of attached peripherals
local peripherals      = {}

--Listeners
local addedListeners   = {}
local removedListeners = {}
local rewrapListeners  = {}
local eventListeners = {
    [ "added"   ] = addedListeners,
    [ "removed" ] = removedListeners,
    [ "rewrap"  ] = rewrapListeners,
}




--Runs when a peripheral has been added
local function onAdded( side, t )
    for k, v in pairs( addedListeners ) do
        local success, err = pcall( k, side, t )
        if not success then print( err ) end
    end
end

--Runs when a peripheral has been removed
local function onRemoved( side, t )
    for k, v in pairs( removedListeners ) do
        local success, err = pcall( k, side, t )
        if not success then print( err ) end
    end
end

--Runs when a peripheral should be rewrapped
local function onShouldRewrap( side, t )
    for k, v in pairs( rewrapListeners ) do
        local success, err = pcall( k, side, t )
        if not success then print( err ) end
    end
end

--Your script should call this at startup.
--Makes an initial record of what peripherals are attached to the turtle.
function scan()
    for i, v in ipairs( sides ) do update( v ) end
end

--Called at various points in the code to hint that a peripheral may have been connected / disconnected.
--This is necessary because ComputerCraft's behavior seems to be inconsistent. Examples:
--As might be expected, a "peripheral" event is generated if the player places a disk drive on top of the turtle, and a "peripheral_detach" if the block is mined.
--However doing turtle.equipLeft() when nothing is equipped and a wireless modem item is selected doesn't generate a "peripheral" event.
--Despite this, doing doing turtle.equipLeft() when a wireless modem is equipped and no item is selected generates a "peripheral_detach" event.
--Even if not for these inconsistencies, there's still the issue that the event queue is asynchronous, but the events themselves don't carry enough information.
--Say you have a peripheral, A. Between calls to os.pullEvent(), you attach and remove remove A. This generates a "peripheral" and "peripheral_detach" event.
--When you get around to calling os.pullEvent(), you'll see that /something/ was attached on top, but to see what type of peripheral was attached,
--you have to do peripheral.getType( "top" ). The only problem is that this returns what is _currently_ attached rather than what was attached at the time that event was queued!
--getType would therefore unexpectedly return nil while you were handling a "peripheral" event.
function update( side )
    local old = peripherals[ side ]
    local t = peripheral.getType( side )
    if old == nil and t ~= nil then
        peripherals[ side ] = t
        onAdded( side, t )
        --print( string.format( "Peripheral attached on %s", side ) )
    elseif old ~= nil and t == nil then
        peripherals[ side ] = nil
        onRemoved( side, old )
        --print( string.format( "Peripheral detached on %s", side ) )
    elseif old ~= nil and t ~= nil then
        --One peripheral was swapped for another
        if old ~= t then
            peripherals[ side ] = t
            onRemoved( side, old )
            onAdded( side, t )
        --Both peripherals are of the same type; this doesn't mean they're the same peripheral, however.
        --e.g. you could have disconnected from one disk drive and connected to another. This requires re-wrapping the peripheral.
        else
            onShouldRewrap( side, t )
        end
    end
end

--event can be "added", "removed", or "rewrap"
function addListener( event, fn )
    local listeners = eventListeners[ event ]
    if listeners == nil then error( "%s is an invalid event.", 2 ) end
    listeners[ fn ] = true
end
function removeListener( event, fn )
    local listeners = eventListeners[ event ]
    if listeners == nil then error( "%s is an invalid event.", 2 ) end
    listeners[ fn ] = nil
end




--If this is being loaded on a turtle we have some other things we can provide
if turtle ~= nil then




--Maps side => function to equip on that side
local equipSide = {
    [ "left"  ] = turtle.equipLeft,
    [ "right" ] = turtle.equipRight
}

--Maps side => opposite side
local oppositeSide = {
    [ "left"  ] = "right",
    [ "right" ] = "left"
}

--Equips the selected item in a free slot.
--If preferredSide is given, equips the item in that slot.
--If the side is occupied, behavior is dependent upon "force".
--    If force is true, it swaps the item with the old peripheral, then equips the old peripheral on the opposite side if empty.
--    If force is false or not given, it equips the peripheral in the opposite side if empty.
--This function returns the side the item was equipped on, or nil if the peripheral could not be equipped.
function equip( preferredSide, force )
    if preferredSide ~= nil then
        local equipPreferred = equipSide[ preferredSide ]

        if peripheral.isPresent( preferredSide ) then
            local opposite      = oppositeSide[ preferredSide ]
            local equipOpposite = equipSide[ opposite ]

            if force == true then
                --Swap peripherals
                equipPreferred()
                update( preferredSide )

                --If there's no peripheral on the other side, equip the old peripheral there
                if not peripheral.isPresent( opposite ) then
                    equipOpposite()
                    update( oppositeSide )
                end
                return preferredSide
            else
                --Equip the peripheral on the opposite side, provided it's free
                if not peripheral.isPresent( opposite ) then
                    equipOpposite()
                    update( oppositeSide )
                    return oppositeSide
                end

                --If not, fail.
                return nil
            end

            return nil
        else
            equipPreferred()
            return preferredSide
        end
    else
        if     not peripheral.isPresent( "left" )  then
            turtle.equipLeft()
            update( "left" )
            return "left"
        elseif not peripheral.isPresent( "right" ) then
            turtle.equipRight()
            update( "right" )
            return "right"
        else
            return nil
        end
    end
end




end