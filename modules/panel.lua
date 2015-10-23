require( "rect" )

local mouseCapturePanel = nil

--panel
local c = {}

local updateListeners = {}
function needsUpdate()
    for k,v in pairs( updateListeners ) do
        pcall( k )
    end
end

function addUpdateListener( fn )
    updateListeners[fn]=true
end

function removeUpdateListener( fn )
    updateListeners[fn]=nil
end

function c:init()
    self.bounds = new.rect( 0,0,0,0 )
    
    self.parent = nil
    self.children = {}
    
    --The child with input focus
    --If this is nil, the focus is on this panel
    self.focusChild = nil
    
    self.visible = true
    self.backgroundColor = colors.black
end

function c:setParent( p )
    local oldp = self.parent
    self.parent = p
    
    --Did the parent change?
    if oldp ~= p then
    
        --Remove this panel from its previous parent
        if oldp ~= nil then
            for i,v in ipairs( oldp.children ) do
                if v == c then
                    table.remove( oldp.children, i )
                    break
                end
            end
            
        --Otherwise, add this panel to its new parent.
        --note: we know oldp == nil, and oldp ~= p.
        --This tells us that p ~= nil.
        else
            table.insert( p.children, self )
        end
        
        needsUpdate()
    end
end

--Returns the parent panel;
--That is, the panel that this panel is a child of
--If this returns nil, this is the top-level panel in the hierarchy
function c:getParent()
    return self.parent
end

--Returns a list of child panels
function c:getChildren()
    return self.children
end

--Sets whether or not the panel is visible
function c:setVisible( visible )
    local old = self.visible
    self.visible = visible
    
    if old ~= visible then
        needsUpdate()
    end
end

--Returns whether or not the panel is visible
function c:getVisible()
    return self.visible
end

--Sets the bounds of the panel (a rectangle)
function c:setBounds( r )
    local old = self.bounds
    self.bounds = r
    
    if old ~= r then
        needsUpdate()
    end
end

--Returns the position of the panel
function c:getBounds()
    return self.bounds
end

--Dispatches an event across the focus chain.
--Event handlers are called in a bottom-to-top order in the chain.
--e.g. if the panel hierarchy looks like this:
--       A
--      / \
--     B   C
--    / \
--   D   E
--...and A's focusChild is B, and B's focusChild is nil,
--then the focus chain would look like A->B.
--When you call A:dispatch( "key" ), it calls B:key(),
--and if B:key() returns a value other than true,
--this will be followed by A:key().
function c:keyDispatch( event, ... )
    if self.focusChild ~= nil and self.focusChild:dispatch( event, ... ) == true then
        return true
    end
    return self[event]( self, ... )
end

--Convert screen coordinates to coordinates relative to the upper-left corner of this panel
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

--Your event loop should call this instead of :mouseDispatch()
function c:rootMouseDispatch( event, x, y, ... )
    if mouseCapturePanel ~= nil then
        local x2, y2 = mouseCapturePanel:screenToLocal( x, y )
        return mouseCapturePanel[ event ]( mouseCapturePanel, x2, y2, ... )
    end

    return self:mouseDispatch( event, x, y, ... )
end

--Dispatches an event across all the panels beneath the given point (x, y), in uppermost to lowermost order.
--x, y is expected to be relative to the upper-left corner of this panel's parent (or 0,0 if it has no parent).
function c:mouseDispatch( event, x, y, ... )
    --If this panel is invisible or the click landed outside of its bounds.
    if not self.visible or not self.bounds:contains( x, y ) then return false end

    --Adjust coords to be relative to top-left corner of this panel.
    x = x - self.bounds.l
    y = y - self.bounds.t

    local children = self.children
    for i = #children, 1, -1 do
        if children[i]:mouseDispatch( event, x, y, ... ) == true then return true end
    end
    return self[ event ]( self, x, y, ... )
end

--If mouseCapture is true, this panel will capture all mouse events, regardless of whether the mouse is hovering over it or not.
--If mouseCapture is false.
function c:setMouseCapture( mouseCapture )
    if mouseCapture then
        if mouseCapturePanel == nil then mouseCapturePanel = self end
    elseif mouseCapturePanel == self then mouseCapturePanel = nil
    end
end

--Default event handlers do nothing
function c:onKeyDown( key, held )
end
function c:onKeyUp( key, held )
end
function c:onMouseDown( x, y, button )
end
function c:onMouseUp( x, y, button )
end
function c:onMouseDrag( x, y, button )
end
function c:onMouseScroll( x, y, dir )
end

--Directs the focus chain towards one of the children of this panel
local function focusChild( self, child )
    if self == nil then return end
    
    self.focusChild = child
    focusChild( self.parent )
end

--Draws the input focus to this child
function c:focus()
    self.focusChild = nil
    focusChild( self.parent, self )
end

--Default draw does nothing
function c:draw( context )

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
end

class.register( "panel", c )