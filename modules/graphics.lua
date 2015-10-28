require( "buffer" )

local c = {}

--Init the graphics. Creates a buffer the same size as the given terminal.
function c:init( terminal )
    local w, h = terminal.getSize()
    self.terminal = terminal
    self.b = new.buffer( w, h )
end

--Sets the terminal the graphics are rendered to.
function c:setTerminal( terminal )
    self.terminal = term
end

--Returns the terminal the graphics are rendered to.
function c:getTerminal()
    return self.terminal
end

--Resize the buffer
function c:resize( size )
    self.b:setSize( size )
end

--Fully redraws the screen
function c:redraw()
    local terminal = self.terminal
    local b        = self.b
    local size     = b:getSize()
    local w, h     = size.width, size.height
    local ch, fg, bg
    for y = 1, h do
        for x = 1, w do
            terminal.setCursorPos( x, y )
            ch, fg, bg = b:get( x - 1, y - 1 )
            terminal.setTextColor( fg )
            terminal.setBackgroundColor( bg )
            terminal.write( ch )
        end
    end
end

--Draws changes to the screen
function c:draw()
    local terminal = self.terminal
    local b = self.b
    local ch, fg, bg
    b:forEachUpdate( function( x, y )
        ch, fg, bg = b:get( x, y )
        terminal.setCursorPos( x + 1, y + 1 )
        terminal.setTextColor( fg )
        terminal.setBackgroundColor( bg )
        terminal.write( ch )
    end )
    b:clearUpdates()
end

--Resets the graphics. This is best called during cleanup.
--This function positions the cursor at the top-left, sets foreground and background colors
--to their defaults (white and black respectively), then clears the screen.
function c:reset()
    local terminal = self.terminal
    terminal.setCursorPos( 1, 1 )
    terminal.setTextColor( colors.white )
    terminal.setBackgroundColor( colors.black )
    terminal.clear()
end

--Returns a context for the buffer that you can draw with
function c:getContext()
    return self.b:getContext()
end

class.register( "graphics", c )