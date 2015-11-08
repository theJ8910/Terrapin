require( "ui.panel" )
require( "layout.fill" )
require( "math2.rect" )

--rootPanel
local c = {}

--Root panels occupy the full space of the given terminal.
--When the terminal resizes, the root panel resizes.
function c:init( terminal )
    self.base.init( self )

    self.layoutHandler     = new.fillLayout()
    self.terminal          = terminal
    self.mouseCapturePanel = nil
    self.focusPanel        = nil

    self:onTerminalResized()
end

function c:onTerminalResized()
    --Match panel to size of terminal
    local w, h = self.terminal.getSize()
    self:setBounds( new.rect( 0, 0, w, h ) )
end

--Root panels are at the top of the hierarchy
function c:setParent( p )
    return false
end
function c:getParent()
    return nil
end

--Sets the panel currently capturing mouse events.
--Set to nil for normal behavior.
function c:setMouseCapturePanel( mouseCapturePanel )
    self.mouseCapturePanel = mouseCapturePanel
end

--Returns the panel currently capturing mouse events, or nil if nothing is currently capturing.
function c:getMouseCapturePanel()
    return self.mouseCapturePanel
end

--Sets the panel holding keyboard focus.
function c:setFocusPanel( focusPanel )
    if focusPanel ~= nil and not focusPanel:isFocusable() then return end

    local old = self.focusPanel
    self.focusPanel = focusPanel

    --Run onBlur and onFocus events on the previous and new panels, respectively (and in that order)
    if old ~= nil        then old:event( "onBlur" )         end
    if focusPanel ~= nil then focusPanel:event( "onFocus" ) end
end

--Returns the panel currently holding keyboard focus, or nil if nothing is focused.
function c:getFocusPanel()
    return self.focusPanel
end

--Your program should call this when someone performs a mouse-related event at (x, y) on the terminal.
--Returns true if a panel consumed the event, false otherwise.
function c:mouseDispatch( event, x, y, ... )
    local pnl, cX, cY

    --Is a panel currently capturing the mouse?
    local capture = self.mouseCapturePanel
    if capture ~= nil then
        pnl = capture
        cX, cY = capture:screenToLocal( x, y )
    --If not, determine which panel the mouse was hovering, and where this is relative to that panel.
    else
        pnl, cX, cY = self:getPanelAt( x, y )
    end

    if pnl == nil then return false end

    --If we pressed the mouse down on this panel, try to move focus to it.
    if event == "onMouseDown" then self:setFocusPanel( pnl ) end

    --Run the event
    return pnl:event( event, cX, cY, ... )
end

--Your program should call this when someone performs a keyboard-related event on the terminal.
--Returns true if a panel consumed the event, false otherwise.
function c:keyboardDispatch( event, ... )
    local focus = self.focusPanel
    if focus ~= nil then
        return focus:event( event, ... )
    end
    return false
end

--Default draw does nothing
function c:draw( context )
    -- local b = self:getBounds()
    -- context:setCharacter( " " )
    -- context:setForeground( colors.white )
    -- context:setBackground( colors.gray )
    -- context:drawRectangle( b.l, b.t, b.r, b.b )
end

class.register( "rootPanel", c, "panel" )