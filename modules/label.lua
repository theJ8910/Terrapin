require( "panel" )

local c = {}

function c:init()
    self.base.init( self )
    self.text = ""
end

function c:setText( text )
    local old = self.text
    self.text = text
    
    if self.text ~= old then panel.needsUpdate() end
end

function c:getText()
    return self.text
end

function c:draw( context )
    context:drawText( 0, 0, self.text )
end

class.register( "label", c, "panel" )