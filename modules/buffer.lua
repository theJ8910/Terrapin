require( "math2.point" )
require( "math2.rect" )
require( "util" )
require( "ids" )
require( "serialize" )


local colorToColorEnum = {
    [colors.white]     = 0,
    [colors.orange]    = 1,
    [colors.magenta]   = 2,
    [colors.lightBlue] = 3,
    [colors.yellow]    = 4,
    [colors.lime]      = 5,
    [colors.pink]      = 6,
    [colors.gray]      = 7,
    [colors.lightGray] = 8,
    [colors.cyan]      = 9,
    [colors.purple]    = 10,
    [colors.blue]      = 11,
    [colors.brown]     = 12,
    [colors.green]     = 13,
    [colors.red]       = 14,
    [colors.black]     = 15
}

local colorEnumToColor = {
    [ 0] = colors.white,
    [ 1] = colors.orange,
    [ 2] = colors.magenta,
    [ 3] = colors.lightBlue,
    [ 4] = colors.yellow,
    [ 5] = colors.lime,
    [ 6] = colors.pink,
    [ 7] = colors.gray,
    [ 8] = colors.lightGray,
    [ 9] = colors.cyan,    
    [10] = colors.purple,
    [11] = colors.blue,
    [12] = colors.brown,
    [13] = colors.green,
    [14] = colors.red,
    [15] = colors.black
}

--Returns a 16-bit encoding for the combination of a character code, foreground color, and background color
function encode( c, fg, bg )
    return c + 256*colorToColorEnum[fg] + 4096*colorToColorEnum[bg]
end

--Returns the character, foreground color, and background color of the given encoding.
function decode( encoding )
    return string.char(                    encoding % 256   )           ,
           colorEnumToColor[ math.floor( ( encoding % 4096  ) / 256  ) ],
           colorEnumToColor[ math.floor( ( encoding % 65536 ) / 4096 ) ]
end

--Compares two buffers of the same size cell by cell.
--If corresponding cells are different, fn is called.
--fn will be provided with the x and y position of the cells that differ.
function compare( left, right, fn )
    local w = left.size.width
    local h = left.size.height
    
    --They need to be the same size
    if w ~= right.size.width or h ~= right.size.height then return end
    
    for y = 0, h-1 do
        for x = 0, w-1 do
            if left[x+w*y] ~= right[x+w*y] then fn( x, y ) end
        end
    end
end

--buffer
local c = {}

function c:init( w, h )
    self.size = {
        ["width"]  = w,
        ["height"] = h
    }
    
    for i = 0, w * h - 1 do
        self[ i ] = 61472      --space character, white foreground, black background, no update
    end
    return t
end

--Iterates over the update buffer and calls fn( x, y ) for each cell marked as being updated.
function c:forEachUpdate( fn )
    local w = self.size.width
    for i = 0, w * self.size.height - 1 do
        if bit.band( self[i], 65536 ) then fn( i % w, math.floor( i / w ) ) end
    end
end

--Clears the update buffer
function c:clearUpdates()
    for i = 0, self.size.width * self.size.height - 1 do
        self[ i ] = bit.band( self[i], 65535 )
    end
end

function c:setSize( w, h )
    local newCount = w * h
    local oldCount = self.size.width * self.size.height
    self.size.width  = w
    self.size.height = h

    --Clear buffer
    for i = 0, newCount - 1 do
        self[ i ] = 127008      --space character, white foreground, black background, has update
    end
    
    --Delete any remaining unused stuff
    for i = newCount, oldCount - 1 do
        self[ i ] = nil
    end
end

function c:getSize()
    return self.size
end

--Sets the character, foreground color, and background color of a cell
--Note: If the foreground and background color match, interpret this as the cell having a transparent background
--Note: 0,0 is the upper-left corner
function c:set( x, y, c, fg, bg )
    self:rawset( x + y * self.size.width, encode( c, fg, bg ) )
end

--Same as set, but takes an index i instead of x, y coords.
function c:rawset( i, encoding )
    --No change
    if bit.band( self[ i ], 65535 ) == encoding then return end

    self[ i ] = bit.bor( encoding, 65536 )
end

--Returns the character, foreground color, and background color used for the pixel at x, y
--Note: 0,0 is the upper-left corner
function c:get( x, y )
    return decode( self[ x + y * self.size.width ] )
end

function c:getSerialID()
    return ids.BUFFER
end

function c:save( writer )
    writer:writeUnsignedInt16( self.size.width )
    writer:writeUnsignedInt16( self.size.height )
    for i = 0, self.size.width * self.size.width - 1 do
        writer:writeUnsignedInt16( bit.band( self[i], 65535 ) )
    end
end

function c:load( reader )
    self.size.width  = reader:readUnsignedInt16()
    self.size.height = reader:readUnsignedInt16()
    for i = 0, self.size.width * self.size.height do
        self[i] = reader:readUnsignedInt16()
    end
end

function c:getContext()
    return new.bufferContext( self )
end

class.register( "buffer", c )

serialize.register( function( serialID ) return new.buffer( 0, 0 ) end, ids.BUFFER )




--bufferContext
local c = {}

function c:init( buffer )
    local s = buffer:getSize()
    
    self.buffer     = buffer
    self.stateStack = {}
    
    self.fg        = colors.white
    self.bg        = colors.black
    self.c         = string.byte( " " )

    self.translate = new.point( 0, 0 )
    self.clip      = new.rect( 0, 0, s.width, s.height )
end

function c:draw( x, y )
    --Shift drawing coordinates according to translate
    x = x + self.translate.x
    y = y + self.translate.y
    
    --Don't allow drawing outside of the rectangle
    if not self.clip:contains( x, y ) then return end
    
    --Draw it in the underlying buffer
    self.buffer:set( x, y, self.c, self.fg, self.bg )
end

--Draws the current character with the current background color and foreground color in the given rectangle
function c:drawRectangle( left, top, right, bottom )
    local b = self.buffer
    local w = b.size.width
    local enc = encode( self.c, self.fg, self.bg )
    
    --Shift the rectangle by "translate",
    --Then get the intersect (sort of; even if they don't intersect, it returns a rectangle with a 0 width and/or height)
    --of the given rectangle and the clipping rectangle
    left   = util.clamp( left   + self.translate.x, self.clip.l, self.clip.r )
    top    = util.clamp( top    + self.translate.y, self.clip.t, self.clip.b )
    right  = util.clamp( right  + self.translate.x, self.clip.l, self.clip.r )
    bottom = util.clamp( bottom + self.translate.y, self.clip.t, self.clip.b )
    
    local i
    for y=top, bottom-1 do
        i = y * w + left
        for x=left, right-1 do
            b:rawset( i, enc )
            i = i + 1
        end
    end
end

function c:drawText( x, y, str )
    --Translate x, y appropriately
    x = x + self.translate.x
    y = y + self.translate.y
    
    --Don't allow drawing outside of the clipping rectangle
    if y < self.clip.t and y >= self.clip.b then return false end
    
    --Clip written text. Detect where the first character will be drawn
    local xBegin = util.clamp( x, self.clip.l, self.clip.r )
    
    --Determine the indices of the first and last characters to be drawn in the string,
    --with 1 being the first character in the string, 2 being the second, etc
    --These could potentially be invalid indices if the entire string is outside of the clipping rectangle.
    --If they are, however, both iBegin and iEnd will be the same index.
    local iBegin = xBegin - x + 1
    local iEnd   = util.clamp( x + #str, self.clip.l, self.clip.r ) - x
    
    --Find where in the buffer we're going to draw to
    local b  = self.buffer
    local bp = xBegin + y * b.size.width
    
    --Draw characters one by one
    for i = iBegin, iEnd do
        b:rawset( bp, encode( string.byte( str, i ), self.fg, self.bg ) )
        bp = bp + 1
    end
end

--Push a copy of the current state to the state stack
function c:pushState()
    table.insert(
        self.stateStack,
        {
            ["fg"]        = self.fg,
            ["bg"]        = self.bg,
            ["c"]         = self.c,
            ["clip"]      = self.clip:copy(),
            ["translate"] = self.translate:copy()
        }
    )
end

--Pops the current state from the stack
function c:popState()
    local state = table.remove( self.stateStack )
    for k,v in pairs( state ) do
        self[k] = v
    end
end

--Sets the background color
function c:setBackground( bg )
    self.bg = bg
end

--Returns the background color
function c:getBackground()
    return self.bg
end

--Sets the foreground color
function c:setForeground( fg )
    self.fg = fg
end

--Returns the foreground color
function c:getForeground()
    return self.fg
end

--Sets the character that gets drawn
function c:setCharacter( c )
    self.c = string.byte( c )
end

--Returns the character that gets drawn
function c:getCharacter()
    return string.char( self.c )
end

--Sets the clipping rectangle
function c:setClip( r )
    local s = self.buffer.size
    self.clip = new.rect(
        math.max( r.l, 0 ),
        math.max( r.t, 0 ),
        math.min( r.r, s.width ),
        math.min( r.b, s.height )
    )
end

--Returns the current clipping rectangle
function c:getClip()
    return self.clip
end

--Sets the translation
function c:setTranslate( t )
    self.translate = t
end

--Returns the translation
function c:getTranslate()
    return self.translate
end

class.register( "bufferContext", c )