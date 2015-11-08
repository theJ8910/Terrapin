require( "panel" )

local c = {}

function c:init()
    self.base.init( self )
    self.items       = {}
    self.itemToIndex = {}
end

--Adds item to the list at the given index between [1,n+1], or at the end of the list if an index is not given.
--Returns the index the item was inserted at.
function c:addItem( item, i )
    if i == nil then i = #t + 1 end
    
    table.insert( self.items, i, item )
    self.itemToIndex[item] = i

    panel.needsUpdate()
    return i
end

--Removes the given item
function c:removeItem( item )
    local i = self.itemToIndex[ item ]
    if i == nil then return false end

    table.remove( self.items, i )
    self.itemToIndex[ item ] = nil

    panel.needsUpdate()
    return true
end

--Removes the item at the given index
function c:removeIndex( i )
    local item = self.items[ i ]
    if item == nil then return false end

    table.remove( self.items, i )
    self.itemToIndex[ item ] = nil

    panel.needsUpdate()
    return true
end

function c:draw( context )
    --
end

class.register( "list", c, "panel" )