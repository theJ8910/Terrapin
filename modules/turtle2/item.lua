if turtle == nil then return error( "This module can only be used by a turtle." ) end




--Keep track of basic details about stored items
local items = {}

--Listeners
local addedListeners         = {}
local removedListeners       = {}
local amountChangedListeners = {}
local eventListeners = {
    [ "added"         ] = addedListeners,
    [ "removed"       ] = removedListeners,
    [ "amountChanged" ] = amountChangedListeners,
}




--Runs when an item has been added
--newItem contains basic details about the item (name, damage, count)
local function onAdded( slot, newItem )
    for k, v in pairs( addedListeners ) do
        local success, err = pcall( k, slot, newItem )
        if not success then print( err ) end
    end
end

--Runs when an item has been removed
local function onRemoved( slot, oldItem )
    for k, v in pairs( removedListeners ) do
        local success, err = pcall( k, slot, oldItem )
        if not success then print( err ) end
    end
end

--Runs when the number of items in a stack changes
local function onAmountChanged( slot, item, oldCount, newCount )
    for k, v in pairs( amountChangedListeners ) do
        local success, err = pcall( k, slot, item, oldCount, newCount )
        if not success then print( err ) end
    end
end

--Returns true if two items are of the same name & damage/meta value.
--Ignores count for now
local function itemsEqual( left, right )
    return left.name == right.name and left.damage == right.damage
end




--Your script should call this at startup.
--Makes an initial record of what items the turtle is carrying.
function scan()
    for slot, item in all() do update( slot, item ) end
end

--Updates our record of what a particular slot is carrying
--Calls onAdded / onRemoved depending on what has changed
function update( slot, newItem )
    local oldItem = items[ slot ]
    items[ slot ] = newItem

    --Item added
    if oldItem == nil and newItem ~= nil then
        onAdded( slot, newItem )
        --print( string.format( "Item was added on slot %d", slot ) )
    --Item removed
    elseif oldItem ~= nil and newItem == nil then
        onRemoved( slot, oldItem )
        --print( string.format( "Item was removed on slot %d", slot ) )
    --There was an item here before, and there is now
    elseif oldItem ~= nil and newItem ~= nil then
        --The items don't match; old item was swapped out for a new one
        if not itemsEqual( oldItem, newItem ) then
            onRemoved( slot, oldItem )
            onAdded( slot, newItem )
            --print( string.format( "Item was swapped on slot %d", slot ) )
        --Items match, but count has changed
        elseif oldItem.count ~= newItem.count then
            onAmountChanged( slot, newItem, oldItem.count, newItem.count )
            --print( string.format( "Item in slot %d's count has changed from %d to %d", slot, oldItem.count, newItem.count ) )
        end
    end
end

--Iterator returned by item.all().
--Takes two arguments, _ and i.
--    _ is unused and is always nil.
--    i is the previous slot that was iterated over and will be 0 if there was no previous slot.
--Returns i, v:
--    i is the slot number (between 1 and 16).
--    v is information about the item in that slot. If the slot is empty, this will be nil.
--    Otherwise, v will be a table containg name, damage, and count.
--    See http://www.computercraft.info/wiki/Turtle.getItemDetail for more information.
local function nextItem( _, i )
    i = i + 1
    if i > 16 then return end
    return i, turtle.getItemDetail( i )
end

--Can be used with a for-in loop to iterate over items the turtle has.
--See next_item for more information.
function all()
    return nextItem, nil, 0
end

--event can be "added", "removed", or "amountChanged"
function addListener( event, fn )
    local listeners = eventListeners[ event ]
    if listeners == nil then error( string.format( "%s is an invalid event.", tostring( event ) ), 2 ) end
    listeners[ fn ] = true
end
function removeListener( event, fn )
    local listeners = eventListeners[ event ]
    if listeners == nil then error( string.format( "%s is an invalid event.", tostring( event ) ), 2 ) end
    listeners[ fn ] = nil
end

