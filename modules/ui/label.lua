require( "ui.panel" )

local c = {}

local defaultSize = new.sizeRange( 0, 0, 1, 1 )

function c:init()
    self.base.init( self )

    self.text = ""
    self:setSizeRange( defaultSize )
end

function c:setText( text )
    local old = self.text
    self.text = text

    if self.text ~= old then
        local len = #text
        self:setSizeRange( new.sizeRange( len, len, 1, 1 ) )
        self:invalidateLayout()
        self:redraw()
    end
end

function c:getText()
    return self.text
end

function c:draw( context )
    context:setForeground( colors.white )
    context:setBackground( colors.black )
    context:drawText( 0, 0, self.text )
end

class.register( "label", c, "panel" )