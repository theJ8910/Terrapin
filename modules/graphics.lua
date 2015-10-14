require( "buffer" )

local c = {}

--Init the graphics. Create a buffer w x h cells large.
function c:init( w, h )
    self.b = new.buffer( w, h )
end

--Resize the buffer
function c:resize( size )
    self.b:setSize( size )
end

--Fully redraws the screen
function c:redraw()
    local b = self.b
    local ch, fg, bg
    local size = b:getSize()
    for y = 1, size.height do
        for x = 1, size.width do
            term.setCursorPos( x, y )
            ch, fg, bg = b:get( x-1, y-1 )
            term.setTextColor( fg )
            term.setBackgroundColor( bg )
            term.write( ch )
        end
    end
end

--Draws changes to the screen
function c:draw()
    local b = self.b
    local ch, fg, bg
    b:forEachUpdate( function( x, y )
        ch, fg, bg = b:get( x, y )
        term.setCursorPos( x + 1, y + 1 )
        term.setTextColor( fg )
        term.setBackgroundColor( bg )
        term.write( ch )
    end )
    b:clearUpdates()
end

--Resets the graphics. This is best called during cleanup.
--This function positions the cursor at the top-left, sets foreground and background colors
--to their defaults (white and black respectively), then clears the screen.
function c:reset()
    term.setCursorPos( 1, 1 )
    term.setTextColor( colors.white )
    term.setBackgroundColor( colors.black )
    term.clear()
end

--Returns a context for the buffer that you can draw with
function c:getContext()
    return self.b:getContext()
end

class.register( "graphics", c )