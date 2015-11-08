--Terminology used in this file:
--* value is a measure of how much a scrollbar has been scrolled.
--* min is the minimum value.
--* max is the maximum value.
--* extent is the size of the viewport in scroll units.
--* pos is a number indicating a position on the scrollable area of the scrollbar.
--* size is how physically wide / tall the scrollable area is.
--  This is usually the width / height of the scrollbar minus the width / height of the buttons.
--* puckSize is how physically wide / tall the scrollbar puck is.
require( "ui.panel" )
require( "math2.rect" )
require( "math2.point" )
require( "util" )
require( "timer" )

--Valid orientations for scrollbars.
VERTICAL   = 0
HORIZONTAL = 1

--Size ranges for vertical and horizontal scrollbars, respectively.
local verticalSizeRange   = new.sizeRange( 1, 1, 2, math.huge )
local horizontalSizeRange = new.sizeRange( 2, math.huge, 1, 1 )

--Color scheme
local puckColor         = colors.blue
local puckDisabledColor = colors.lightGray

--scrollbar
local c = {}

--Returns how physically wide / tall the puck is (at minimum, 1).
local function getPuckSize( min, max, extent, size )
    if size <= 0 then return 1 end

    local valueSpace = max - min
    if valueSpace <= 0 then return size end

    return math.max( 1, util.round( size * extent / valueSpace ) )
end

--Returns the position corresponding to the given value, rounded to the nearest integer.
--The returned position is guaranteed to be in the range [ 0, size - puckSize ]
--if the given value is in the range[ min, max - extent ].
local function valueToPos( value, min, max, extent, size, puckSize )
    local scrollSpace = size - puckSize
    if scrollSpace <= 0 then return 0 end

    local valueSpace = max - min - extent
    if valueSpace <= 0 then return 0 end

    return util.round( scrollSpace * ( value - min ) / valueSpace )
end

--Returns the value corresponding to the given position, rounded to the nearest integer.
--The returned value is guaranteed to be in the range [ min, max - extent ]
--if the given position is in the range [0, size - puckSize].
local function posToValue( pos, min, max, extent, size, puckSize )
    local scrollSpace = size - puckSize
    if scrollSpace <= 0 then return min end

    local valueSpace = max - min - extent
    return min + util.round( valueSpace * pos / scrollSpace )
end

function c:init()
    self.base.init( self )

    self.direction       = VERTICAL --Orientation of the scrollbar
    self.enabled         = true     --Can the user manipulate the scrollbar?
    self.value           = 0        --The current scroll amount.
    self.min             = 0        --The minimum scroll amount.
    self.max             = 2        --The maximum scroll amount.
    self.extent          = 1        --The extent of the scrollable area (determines the size of the scrollbar).
    self.increment       = 1        --How much the scrollbar moves when an arrow key or the increment / decrement button is pressed.
    self.autoscrollTimer = nil      --Autoscroll timer ID.
    self.scrollListeners = {}

    self:setSizeRange( verticalSizeRange )

    --UI elements
    local pnl

    --Puck
    pnl = new.scrollbarPuck()
    pnl:setParent( self )
    self.puck = pnl

    --Decrement (up / left) arrow button
    pnl = new.button()
    pnl:setText( "^" )
    pnl:setParent( self )
    pnl:addPressListener( function() self:startAutoScroll( -self.increment, self.min ) end )
    pnl:addReleaseListener( function() self:stopAutoScroll() end )
    self.decButton = pnl

    --Increment (down / right) arrow button
    pnl = new.button()
    pnl:setText( "v" )
    pnl:setParent( self )
    pnl:addPressListener( function() self:startAutoScroll( self.increment, self.max ) end )
    pnl:addReleaseListener( function() self:stopAutoScroll() end )
    self.incButton = pnl
end

function c:destroy()
    self:stopAutoScroll()
end

function c:startAutoScroll( increment, to )
    --Cancel a previous autoscroll if one is in progress
    self:stopAutoScroll()

    --This function scrolls by the given amount (but not past the given position) each time it's called.
    local function tick()
        local nextValue  = self:getValue() + increment

        --Don't scroll any farther than the desired position.
        if ( increment > 0 and nextValue > to ) or ( increment < 0 and nextValue < to ) then nextValue = to end

        self:setValue( nextValue )
    end

    --Tick once as soon as this function is called
    tick()

    --After half a second passes, tick once again, then repetitively every 1/10th of a second
    self.autoscrollTimer = timer.start( 0.5, function()
        tick()
        self.autoscrollTimer = timer.repeating( 0.10, tick )
    end )
end

--Stop autoscrolling (or cancel the timer if we haven't started yet)
function c:stopAutoScroll()
    timer.cancel( self.autoscrollTimer )
end

--Positions the increment / decrement buttons and the puck within the scrollbar.
function c:layoutHandler()
    local b = self:getBounds()
    local value, min, max, extent = self.value, self.min, self.max, self.extent

    --The increment and decrement buttons are 1x1.
    self.decButton:setBounds( new.rect( 0, 0, 1, 1 ) )
    if self.direction == VERTICAL then
        local h = b:getHeight()
        self.incButton:setBounds( new.rect( 0, h - 1, 1, h ) )

        --Subtract buttons from height
        h = math.max( 0, h-2 )

        --The puck has a width of 1, and a minimum height of 1.
        local puckH = getPuckSize( min, max, extent, h )
        local puckY = 1 + valueToPos( value, min, max, extent, h, puckH )
        self.puck:setBounds( new.rect( 0, puckY, 1, puckY + puckH ) )
    elseif self.direction == HORIZONTAL then
        local w = b:getWidth()
        self.incButton:setBounds( new.rect( w - 1, 0, w, 1 ) )

        --Subtract buttons from width
        w = math.max( 0, w-2 )

        --The puck has a height of 1, and a minimum width of 1.
        local puckW = getPuckSize( min, max, extent, w )
        local puckX = 1 + valueToPos( value, min, max, extent, w, puckW )
        self.puck:setBounds( new.rect( puckX, 0, puckX + puckW, 1 ) )
    end
end

function c:isFocusable()
    return true
end

function c:addScrollListener( fn )
    self.scrollListeners[ fn ] = true
end

function c:removeScrollListener( fn )
    self.scrollListeners[ fn ] = nil
end

--Called when the scrollbar's scroll amount changes.
function c:eventScroll()
    for k,v in pairs( self.scrollListeners ) do
        local success, err = pcall( k, self, self.value )
        if not success then print( err ) end
    end
end

--Set the direction of the scrollbar.
--Should be one of scrollbar.HORIZONTAL, scrollbar.VERTICAL
function c:setDirection( direction )
    if direction ~= VERTICAL and direction ~= HORIZONTAL then
        return error( string.format( "Invalid direction: %s", tostring( direction ) ) )
    end

    local old = self.direction
    self.direction = direction

    if direction ~= old then
        if     direction == VERTICAL   then
            self:setSizeRange( verticalSizeRange   )
            self.decButton:setText( "^" )
            self.incButton:setText( "v" )
        elseif direction == HORIZONTAL then
            self:setSizeRange( horizontalSizeRange )
            self.decButton:setText( "<" )
            self.incButton:setText( ">" )
        end

        self:invalidateLayout()
        self:redraw()
    end
end

--Returns the direction of the scrollbar.
function c:getDirection()
    return self.direction
end

function c:setEnabled( enabled )
    local old = self.enabled
    self.enabled = enabled

    if old ~= enabled then
        self.decButton:setEnabled( enabled )
        self.incButton:setEnabled( enabled )

        if enabled == false then
            self:stopAutoScroll()
            self:setMouseCapture( false )
            self.puck:stopDragging()
            self.puck:redraw()
        end
        self:redraw()
    end
end

function c:getEnabled()
    return self.enabled
end

--Sets the scrollbar's value (the amount it is currently scrolled).
--value is clamped between [min, max-extent].
--A scroll event is triggered if value changes.
function c:setValue( value )
    value = util.clamp( value, self.min, self.max - self.extent )

    local old = self.value
    self.value = value

    if value ~= old then
        self:invalidateLayout()
        self:redraw()
        self:eventScroll()
    end
end

--Returns the scrollbar's value (the amount it is currently scrolled).
function c:getValue()
    return self.value
end

--Scrolls the scrollbar by the given increment.
--increment can be negative or positive.
function c:scrollBy( increment )
    self:setValue( self:getValue() + increment )
end

--Sets the minimum and maximum scroll amounts.
--If the constraint between value, min, max, and extent is violated by the change, the other values may be set as well.
function c:setLimits( min, max )
    local adjMax = max - self.extent
    if min > max then
        max         = min
        self.extent = 0
        adjMax      = min
    elseif min > adjMax then
        self.extent = max - min
        adjMax      = min
    end

    local oldMin = self.min
    local oldMax = self.max
    self.min = min
    self.max = max

    --Note: Extent doesn't change if neither min nor max change.
    if oldMin ~= min or oldMax ~= max then
        if     self.value < min     then self:setValue( min )
        elseif self.value > adjMax  then self:setValue( adjMax )
        end
        self:invalidateLayout()
        self:redraw()
    end
end

--Returns the minimum and maximum scroll amounts.
function c:getLimits()
    return self.min, self.max
end

--Sets the minimum scroll amount.
--If the constraint between value, min, max, and extent is violated by the change, the other values may be set as well.
function c:setMin( min )
    local adjMax = self.max - self.extent
    if min > self.max then
        self.max    = min
        self.extent = 0
        adjMax      = min
    elseif min > adjMax then
        self.extent = self.max - min
        adjMax      = min
    end

    local old = self.min
    self.min = min

    --Note: If min doesn't change, neither do max and extent.
    if old ~= min then
        if self.value < min then self:setValue( min ) end
        self:invalidateLayout()
        self:redraw()
    end
end

--Returns the minimum scroll amount.
function c:getMin()
    return self.min
end

--Sets the maximum scroll amount.
--If the constraint between value, min, max, and extent is violated by the change, the other values may be set as well.
function c:setMax( max )
    local adjMax = max - self.extent
    if self.min > max then
        max = min
        self.extent = 0
        adjMax = min
    elseif min > adjMax then
        self.extent = max - self.min
        adjMax = min
    end

    local old = self.max
    self.max = max

    --Note: If max doesn't change, extent doesn't either.
    if old ~= max then
        if self.value > adjMax then self:setValue( adjMax ) end
        self:invalidateLayout()
        self:redraw()
    end
end

--Returns the maximum scroll amount.
function c:getMax()
    return self.max
end

--Sets the extent of the scrollbar. If the given extent is negative, it will be set to 0.
--If the constraint between value, min, max, and extent is violated by the change, the other values may be set as well.
function c:setExtent( extent )
    extent = math.max( 0, extent )

    local adjMin = self.min + extent
    if adjMin > self.max then
        self.max = adjMin
    end

    local old = self.extent
    self.extent = extent

    --Note: If extent doesn't change, max doesn't either.
    if old ~= max then
        local adjMax = self.max - extent
        if self.value > adjMax then self:setValue( adjMax ) end
        self:invalidateLayout()
        self:redraw()
    end
end

--Returns the extent of the scrollbar.
function c:getExtent()
    return self.extent
end

--Sets the increment amount.
--increment should be a positive number.
function c:setIncrement( increment )
    self.increment = increment
end

--Returns the increment amount.
function c:getIncrement()
    return self.increment
end

--Takes a point local to the scrollbar, (x,y).
--Returns pos, size:
--    pos is the dot product between the given point and the axis of the scroll bar (adjusted to be relative to the beginning of the scroll area).
--        This can be outside of the range [0,size].
--    size is how many pixels large the scrollable area is, with a minimum of 0.
function c:getPosAndSize( x, y )
    local size, pos
    if     self.direction == VERTICAL   then
        size = self:getBounds():getHeight() - 2
        pos = y
    elseif self.direction == HORIZONTAL then
        size = self:getBounds():getWidth()  - 2
        pos = x
    else
        return 0, 0
    end
    return pos - 1, math.max( 0, size )
end

--Tables of directional and universal key handlers
local horizontalKeyHandlers = {
    [203] = function( self ) self:scrollBy( -self.increment ) end, --203 = left arrow
    [205] = function( self ) self:scrollBy(  self.increment ) end  --205 = right arrow
}
local verticalKeyHandlers = {
    [200] = function( self ) self:scrollBy( -self.increment ) end, --200 = up Arrow
    [208] = function( self ) self:scrollBy(  self.increment ) end  --208 = down Arrow
}
local universalKeyHandlers = {
    [201] = function( self ) self:scrollBy( -self.extent )    end, --201 = page up
    [209] = function( self ) self:scrollBy(  self.extent )    end, --209 = page down
    [199] = function( self ) self:setValue( self:getMin() )   end, --199 = home
    [207] = function( self ) self:setValue( self:getMax() )   end  --207 = end
}
--Maps a direction to a table of key handlers for that direction
local directionalKeyHandlers = {
    [HORIZONTAL] = horizontalKeyHandlers,
    [VERTICAL]   = verticalKeyHandlers
}

--The arrow keys, home, end, and page up / page down can be used to scroll the scrollbar.
--The arrow keys move the scrollbar by the scroll increment.
--Home / end move the scrollbar to min / max, respectively.
--Page up / page down move the scrollbar by it's size.
function c:onKeyDown( scancode, held )
    if not self.enabled then return true end

    --Dependent on direction of scrollbar
    local handler
    local keyHandlers = directionalKeyHandlers[ self.direction ]
    if keyHandlers then
        handler = keyHandlers[ scancode ]
        if handler then handler( self ); return true end
    end

    --Independent of scrollbar direction
    handler = universalKeyHandlers[ scancode ]
    if handler then handler( self ); return true end

    --Pressed key isn't one we recognize
    return false
end

function c:onMouseDown( x, y, button )
    if button ~= 1 then return false end
    if not self.enabled then return true end

    local min, max, extent = self.min, self.max, self.extent

    --Find where the mouse was clicked
    local pos, size = self:getPosAndSize( x, y )
    local puckSize  = getPuckSize( min, max, extent, size )

    --Find the value that corresponds to where we clicked.
    --Note: we subtract half the puck's size from the position because we want the middle of the puck to land there.
    local value = posToValue( pos - math.floor( ( puckSize - 1 ) / 2 ), min, max, extent, size, puckSize )

    --Autoscroll to here.
    self:startAutoScroll( value > self.value and extent or -extent, value )
    self:setMouseCapture( true )

    return true
end

function c:onMouseUp( x, y, button )
    if button ~= 1 then return false end
    if not self.enabled then return true end

    self:stopAutoScroll()
    self:setMouseCapture( false )

    return true
end

--When we scroll the mouse wheel, scroll the scrollbar as well.
function c:onMouseScroll( x, y, dir )
    if not self.enabled then return true end

    if dir < 0 then self:scrollBy( -self.increment ) --Up
    else            self:scrollBy(  self.increment ) --Down
    end
    return true
end

--Draws a plain black background.
function c:draw( context )
    local w, h = self:getBounds():getSize()
    context:setCharacter( " " )
    context:setForeground( colors.white )
    context:setBackground( colors.black )
    context:drawRectangle( 0, 0, w, h )
end

class.register( "scrollbar", c, "panel" )




--scrollbarPuck
local c = {}

function c:init()
    self.base.init( self )
    self.dragging = false
    self.draggingFrom = new.point( 0, 0 )
end

function c:onMouseDown( x, y, button )
    if button ~= 1 or self.dragging or not self:getParent().enabled then return false end

    self.dragging = true
    self.draggingFrom:set( x, y )
    self:setMouseCapture( true )

    return true
end

function c:onMouseUp( x, y, button )
    if button ~= 1 or not self.dragging or not self:getParent().enabled then return false end
    self:stopDragging()

    return true
end

function c:stopDragging()
    self.dragging = false
    self:setMouseCapture( false )
end

function c:onMouseDrag( x, y, button )
    if button ~= 1 or not self.dragging then return false end

    --Convert drag coordinates to be relative to our parent, and offset by drag location.
    local b = self:getBounds()
    x = x + b.l - self.draggingFrom.x
    y = y + b.t - self.draggingFrom.y

    --Get our position on and size of the scrollable area
    local p = self:getParent()
    local min, max, extent = p.min, p.max, p.extent
    local pos, size = p:getPosAndSize( x, y )
    local puckSize  = getPuckSize( min, max, extent, size )

    p:setValue( posToValue( pos, min, max, extent, size, puckSize ) )
    return true
end

function c:draw( context )
    local w, h = self:getBounds():getSize()
    context:setCharacter( " " )
    context:setForeground( colors.white )
    context:setBackground( self:getParent().enabled and puckColor or puckDisabledColor )
    context:drawRectangle( 0, 0, w, h )
end

class.register( "scrollbarPuck", c, "panel" )