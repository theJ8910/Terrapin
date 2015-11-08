require( "math2.rect" )
require( "layout.insets" )
require( "layout.sizeRange" )

--panel
local c = {}

NONE  = 0  --Nothing needs to be laid out
SELF  = 1  --This panel needs to be laid out
CHILD = 2  --One or more child panels need to be laid out
BOTH  = 3  --Both this panel and one or more child panels need to be laid out

function c:init()
    --Hierarchy
    self.parent      = nil
    self.children    = {}

    --Layout related
    self.layoutHandler = nil                                         --Object handling the layout for this container
    self.bounds        = new.rect( 0, 0, 0, 0 )                      --Rectangle defining this panel's current bounds, relative to its parent
    self.padding       = new.insets( 0, 0, 0, 0 )                    --Outer spacing
    self.margins       = new.insets( 0, 0, 0, 0 )                    --Inner spacing
    self.sizeRange     = new.sizeRange( 0, math.huge, 0, math.huge ) --Acceptable minimums and maximums for this panel's width and height, respectively.
    self.visible       = true                                        --Invisible panels cannot be seen or interacted with. Furthermore, layout ignores invisible panels.

    --Flags
    self.needsRedraw   = false                                       --Set to true when something occurs that alters the appearance of the panel. Set to false after the panel has been redrawn.
    self.needsLayout   = false                                       --Set to true when something occurs that alters the layout of the panel. Set to false after laying out the panel.

    --Display
    self.opaque          = true                                      --If this is false, this panel is transparent. When a transparent panel needs to be redrawn, its parents must be redrawn as well.
    self.backgroundColor = colors.black
end

--Cleanup hook for the panel. Does nothing by default.
function c:destroy()
end

--Marks this panel and its ascendants as needing its layout recomputed
function c:invalidateLayout()
    local p = self
    repeat
        p:setNeedsLayout( true )
        p = p.parent
    until p == nil
end

--Sets whether this particular panel needs layout recomputed or not
function c:setNeedsLayout( needsLayout )
    self.needsLayout = needsLayout
end

--Returns whether this particular panel needs its layout recomputed or not
function c:getNeedsLayout()
    return self.needsLayout
end

--Marks this panel and its ascendants as needing to be redrawn
function c:redraw()
    local p = self
    repeat
        p:setNeedsRedraw( true )
        p = p.parent
    until p == nil
end

--Set whether this particular panel needs to be redrawn or not
function c:setNeedsRedraw( needsRedraw )
    self.needsRedraw = needsRedraw
end

--Returns whether this particular panel needs to be redrawn or not
function c:getNeedsRedraw()
    return self.needsRedraw
end

--Lays out this panel if it needs it
function c:layout()
    if not self:getNeedsLayout() then return end

    if self.layoutHandler then self.layoutHandler( self ) end
    self:setNeedsLayout( false )
end

--Sets this panel's parent
function c:setParent( p )
    local oldp = self.parent
    self.parent = p

    --If the parent hasn't changed, we can stop here.
    if oldp == p then return end

    --Remove this panel from its previous parent
    if oldp ~= nil then table.remove( oldp.children, oldp:findChild( self ) ) end

    --Add this panel to its new parent.
    if p ~= nil then table.insert( p.children, self ) end
end

--Adds the given panel as a child of this panel.
--pnl is the panel to add.
--position is the position to insert the panel at.
function c:addChild( pnl, position )
    --TODO
end

--Finds the index for the given child panel and returns it.
--Returns nil if the given panel is not a child of this panel.
function c:findChild( pnl )
    for i,v in ipairs( self.children ) do
        if v == pnl then return i end
    end
    return nil
end

--Returns the parent panel;
--That is, the panel that this panel is a child of
--If this returns nil, this is the top-level panel in the hierarchy
function c:getParent()
    return self.parent
end

--Returns the root panel for this panel.
--Starting from this panel, ascends the hierarchy until we locate a panel with no parent (the root panel).
function c:getRoot()
    local p = self
    while p.parent ~= nil do p = p.parent end
    return p
end

--Returns a list of child panels
function c:getChildren()
    return self.children
end

--Sets the margins for the panel.
function c:setMargins( margins )
    local old = self.margins
    self.margins = margins

    if old ~= margins then
        self:invalidateLayout()
    end
end

--Returns the margins for the panel.
function c:getMargins()
    return self.margins
end

--Sets the padding for the panel.
function c:setPadding( padding )
    local old = self.padding
    self.padding = padding

    --If the padding changes, we need to lay out the child.
    if old ~= padding then
        self:invalidateLayout()
    end
end

--Returns the padding for the panel.
function c:getPadding()
    return self.padding
end

--Sets the size range for the panel.
function c:setSizeRange( sizeRange )
    local old = self.sizeRange
    self.sizeRange = sizeRange

    if old ~= sizeRange then
        self:invalidateLayout()
    end
end

--Returns the size range for the panel
function c:getSizeRange()
    return self.sizeRange
end

--Sets whether or not the panel is visible
function c:setVisible( visible )
    local old = self.visible
    self.visible = visible

    if old ~= visible then
        self:invalidateLayout()
        self:redraw()
    end
end

--Returns whether or not the panel is visible
function c:getVisible()
    return self.visible
end

--Returns whether or not the panel is opaque
function c:isOpaque()
    return self.opaque
end

--Sets the bounds of the panel (a rectangle)
function c:setBounds( r )
    local old = self.bounds
    self.bounds = r

    --Bounds describe position and size.
    --Layout doesn't need to be re-performed unless our size changes.
    --However, if position or size changes, we need to redraw.
    if old:getWidth() ~= r:getWidth() or old:getHeight() ~= r:getHeight() then
        self:invalidateLayout()
        self:redraw()
    elseif old.l ~= r.l or old.t ~= r.t then
        self:redraw()
    end
end

--Returns the position of the panel
function c:getBounds()
    return self.bounds
end

--Returns true if the given point is inside of the panel's bounds.
--x, y are local coordinates (relative to the upper-left corner of this panel)
function c:contains( x, y )
    local w, h = self.bounds:getSize()
    return x >= 0 and y >= 0 and x < w and y < h
end

--Convert screen coordinates to local coordinates (relative to the upper-left corner of this panel)
function c:screenToLocal( x, y )
    local p = self
    local b
    repeat
        b = p.bounds
        x = x - b.l
        y = y - b.t
        p = p.parent
    until p == nil

    return x, y
end

--Convert local coordinates (relative to the upper-left corner of this panel) to screen coordinates
function c:localToScreen( x, y )
    local p = self
    local b
    repeat
        b = p.bounds
        x = x + b.l
        y = y + b.t
        p = p.parent
    until p == nil

    return x, y
end

--Returns the uppermost visible panel beneath the point (x, y).
--(x, y) is relative to the upper-left corner of this panel's parent (or the screen if the panel has no parent).
function c:getPanelAt( x, y )
    --If this panel is invisible or the point is outside of its bounds, then neither this panel nor any of its children are beneath this point.
    local b = self.bounds
    if not self.visible or not b:contains( x, y ) then return nil, nil, nil end

    --Adjust coords to be relative to top-left corner of this panel.
    x = x - b.l
    y = y - b.t

    --Recursively check if any of our children were clicked, uppermost child first.
    local children = self.children
    local clicked, cX, cY
    for i = #children, 1, -1 do
        clicked, cX, cY = children[i]:getPanelAt( x, y )
        if clicked ~= nil then return clicked, cX, cY end
    end

    return self, x, y
end

--Bubbles an event upwards through the hierarchy.
--Event handlers are called in a bottom-to-top order in the chain.
--e.g. if the panel hierarchy looks like this:
--       A
--      / \
--     B   C
--    / \
--   D   E
--When you call E:event( "onKeyDown", 57 ),
--it calls E:onKeyDown( 57), then B:onKeyDown( 57 ), then A:onKeyDown( 57 ).
--If a call to onKeyDown were to return true, the event is consumed and does not propagate further up the hierarchy.
--e.g. if E:onKeyDown(57) returned true, the calls to B and A's onKeyDown would not occur.
function c:event( event, ... )
    local p = self
    repeat
        if p[ event ]( p, ... ) then return true end
        p = p.parent
    until p == nil
    return false
end

--Draws the input focus to this child
function c:focus()
    self:getRoot():setFocusPanel( self )
end

--Is this panel currently focused?
function c:isFocused()
    return self:getRoot():getFocusPanel() == self
end

--Can this panel be focused?
--In other words, can keyboard input be directed towards this panel?
--buttons, text boxes, and lists are examples of focusable panels.
--Note that even if a panel is not focusable, it can still receive keyboard input
--if one of it's children is focused and chooses not to consume the key event.
function c:isFocusable()
    return false
end

--If mouseCapture is true, this panel will capture all mouse events, regardless of whether the mouse is hovering over it or not.
--If mouseCapture is false, this panel stops capturing the mouse if it is currently capturing it.
--In either case, if some other panel is currently capturing the mouse, this function does nothing.
function c:setMouseCapture( mouseCapture )
    local root = self:getRoot()
    if mouseCapture then
        if root:getMouseCapturePanel() == nil  then root:setMouseCapturePanel( self ) end
    elseif root:getMouseCapturePanel() == self then root:setMouseCapturePanel( nil )
    end
end

--Renders the panel and all child panels.
function c:drawAll( context )
    --If the panel is not visible we have nothing to draw
    if not self.visible then return end

    --Because we're plan to modify the context's state,
    --we'll push the state so we can return to it later.
    context:pushState()

    --We're going to restrict drawing operations to the subrectangle the panel occupies,
    --and change the translation so that draw operations are relative to the upper-left corner of the panel.
    local c = context:getClip()
    local b = self.bounds
    c = new.rect(
        math.min( c.l + b.l, c.r ),
        math.min( c.t + b.t, c.b ),
        math.min( c.l + b.r, c.r ),
        math.min( c.t + b.b, c.b )
    )
    context:setClip( c )
    context:setTranslate( new.point( c.l, c.t ) )

    --Do panel-specific rendering
    self:draw( context )

    --Draw children in a similar fashion
    for i,v in ipairs( self.children ) do
        v:drawAll( context )
    end

    --Pop the state to restore it to what it once was that we're done drawing this panel and its children
    context:popState()

    --We're finished; this panel has no further drawing to do.
    self:setNeedsRedraw( false )
end

--Default event handlers do nothing
function c:onKeyDown( key, held )      end
function c:onKeyUp( key, held )        end
function c:onMouseDown( x, y, button ) end
function c:onMouseUp( x, y, button )   end
function c:onMouseDrag( x, y, button ) end
function c:onMouseScroll( x, y, dir )  end
function c:onFocus()                   end
function c:onBlur()                    end
-- function c:onShow()                    end
-- function c:onHide()                    end
-- function c:onAdded()                   end
-- function c:onRemoved()                 end
--Default draw does nothing
function c:draw( context )             end

class.register( "panel", c )