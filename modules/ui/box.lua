require( "ui.panel" )
require( "layout.box" )

--box
local c = {}

function c:init( order )
    self.base.init( self )
    self.layoutHandler = new.boxLayout( order )
end

class.register( "box", c, "panel" )