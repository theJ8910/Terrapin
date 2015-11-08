require( "ui.panel" )

--Color scheme
local colorText     = colors.white
local colorReleased = colors.red
local colorPressed  = colors.green
local colorDisabled = colors.gray

--Button
local c = {}

function c:init()
    self.base.init( self )

    self.text             = ""    --What should the button display?
    self.enabled          = true  --Can the button be clicked?
    self.pressed          = 0     --How many things are pressing us?
    self.mousePressed     = false --Is the mouse pressing us?
    self.keyPressed       = false --Is the spacebar pressing us?
    self.clickListeners   = {}
    self.pressListeners   = {}
    self.releaseListeners = {}
end

function c:addClickListener( fn )
    self.clickListeners[ fn ] = true
end

function c:removeClickListener( fn )
    self.clickListeners[ fn ] = nil
end

function c:addPressListener( fn )
    self.pressListeners[ fn ] = true
end

function c:removePressListener( fn )
    self.pressListeners[ fn ] = nil
end

function c:addReleaseListener( fn )
    self.releaseListeners[ fn ] = true
end

function c:removeReleaseListener( fn )
    self.releaseListeners[ fn ] = nil
end

function c:setText( text )
    local old = self.text
    self.text = text
    if old ~= text then
        self:redraw()
    end
end

function c:getText()
    return self.text
end

function c:setEnabled( enabled )
    local old = self.enabled
    self.enabled = enabled

    if old ~= enabled then
        if enabled == false then self:releaseAll() end
        self:redraw()
    end
end

function c:getEnabled()
    return self.enabled
end

function c:click()
    for k,_ in pairs( self.clickListeners ) do k( self ) end
end

--Returns true if we went from released to pressed.
--Returns false otherwise.
function c:press()
    self.pressed = self.pressed + 1

    if self.pressed == 1 then
        for k,_ in pairs( self.pressListeners ) do k( self ) end
        self:redraw()
        return true
    end
    return false
end

--Returns true if we went from pressed to released.
--Returns false otherwise.
function c:release()
    self.pressed = self.pressed - 1

    if self.pressed == 0 then
        for k,_ in pairs( self.releaseListeners ) do k( self ) end
        self:redraw()
        return true
    end
    return false
end

--Forcefully releases the button.
--Returns false if the button wasn't pressed.
--Returns true otherwise.
function c:releaseAll()
    if self.pressed == 0 then return false end

    self.pressed      = 0
    self.mousePressed = false
    self.keyPressed   = false

    self:setMouseCapture( false )
    self:redraw()
    for k,_ in pairs( self.releaseListeners ) do k( self ) end

    return true
end

--Buttons can be focused and pressed with the spacebar
function c:isFocusable()
    return true
end

--Allow pressing the button with the left mouse button
--NOTE: there is currently a bug in computercraft where if you press two mouse buttons
--without releasing the first, a mouseup event will only be generated for the 2nd button.
function c:onMouseDown( x, y, button )
    if button ~= 1 then return false end --1 = left mouse button
    if self.mousePressed or not self.enabled then return true end

    self.mousePressed = true
    self:setMouseCapture( true )

    self:press()
    return true
end
function c:onMouseUp( x, y, button )
    if button ~= 1 then return false end --1 = left mouse button
    if not self.mousePressed or not self.enabled then return true end
    self.mousePressed = false
    self:setMouseCapture( false )

    --Click the button if we're no longer pressed.
    if self:release() and self:contains( x, y ) then self:click() end
    return true
end

--Allow pressing the button with the spacebar
function c:onKeyDown( scancode, held )
    if scancode ~= 57 then return false end --57 = space
    if self.keyPressed or not self.enabled then return true end
    self.keyPressed = true

    self:press()
    return true
end
function c:onKeyUp( scancode, held )
    if scancode ~= 57 then return false end --57 = space
    if not self.keyPressed or not self.enabled then return true end
    self.keyPressed = false

    --Click the button if we're no longer pressed.
    if self:release() then self:click() end

    return true
end

--If keyboard focus changes while we're pressing the button with the space bar, release the key and don't count it as a click.
function c:onBlur()
    if not self.keyPressed then return end
    self.keyPressed = false
    self:release()
end

--Draw a colored rectangle
function c:draw( context )
    local w, h = self.bounds:getSize()
    context:setCharacter( " " )
    context:setForeground( colorText )
    context:setBackground( self.enabled and ( self.pressed > 0 and colorPressed or colorReleased ) or colorDisabled )
    context:drawRectangle( 0, 0, w, h )
    context:drawText( 0, math.floor( ( h - 1 ) / 2 ) , self.text )
end

class.register( "button", c, "panel" )