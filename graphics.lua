require( "class" )
require( "buffer" )

local c = {}

--Init the graphics. Create front and back buffers w x h cells large.
function c:init( w, h )
    self.fb = new.buffer( w, h )
    self.bb = new.buffer( w, h )
end

--Resize the buffers
function c:resize( size )
    self.fb:setSize( size )
    self.bb:setSize( size )
end

--Swap buffers
function c:swapBuffers()
    --Swap the front and back buffers
    local swap = self.bb
    self.bb = self.fb
    self.fb = swap
end

--Fully redraws the screen
function c:redraw()
    self:swapBuffers()
    
    local ch, fg, bg
    local size = self.fb:getSize()
    for y = 1, size.height do
        for x = 1, size.width do
            term.setCursorPos( x, y )
            ch, fg, bg = self.fb:get( x-1, y-1 )
            term.setTextColor( fg )
            term.setBackgroundColor( bg )
            term.write( ch )
        end
    end
end

--Draws changes to the screen
function c:draw()
    self:swapBuffers()
    
    --Compare the two, drawing changed tiles
    buffer.compare( self.fb, self.bb, function( x, y )
        local ch, fg, bg = self.fb:get( x, y )
        term.setCursorPos( x + 1, y + 1 )
        term.setTextColor( fg )
        term.setBackgroundColor( bg )
        term.write( ch )
    end )
end

--Returns a context for the back buffer that you can draw with
function c:getContext()
    return self.bb:getContext()
end

class.register( "graphics", c )