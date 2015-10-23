require( "panel" )

local c = {}

function c:init()
    self.base.init( self )
    self.pressed        = false
    self.clickListeners = {}
end

function c:addClickListener( fn )
    self.clickListeners[ fn ] = true
end

function c:removeClickListener( fn )
    self.clickListeners[ fn ] = nil
end

function c:eventClick()
    for k,_ in pairs( self.clickListeners ) do k() end
end

function c:onMouseDown( x, y, button )
    self.pressed = true
    panel.needsUpdate()

    self:setMouseCapture( true )
end

function c:onMouseUp( x, y, button )
    if self.pressed then
        self.pressed = false
        self:eventClick()

        panel.needsUpdate()
    end
    
    self:setMouseCapture( false )
end

--Draw a colored rectangle
function c:draw( context )
    local w, h = self.bounds:getSize()
    context:setCharacter( " " )
    context:setForeground( colors.white )
    context:setBackground( self.pressed and colors.green or colors.red )
    context:drawRectangle( 0, 0, w, h )
end

class.register( "button", c, "panel" )