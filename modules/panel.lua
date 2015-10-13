require( "rect" )

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
            for k,v in ipairs( oldp.children ) do
                if v == c then
                    table.remove( oldp.children, k )
                    break
                end
            end
            
        --Otherwise, add this panel to its new parent.
        --note: we know oldp == nil, and oldp ~= p.
        --This tells us that p ~= nil.
        else
            table.insert( p.children, self )
        end
        
        panel.needsUpdate()
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
        panel.needsUpdate()
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
function c:dispatch( event, ... )
    if self.focusChild ~= nil and self.focusChild:dispatch( event, ... ) == true then
        return true
    end
    return self[event]( self, ... )
end

--Default key handler does nothing
function c:key( key )

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
    local r = context:getRect()
    local b = self.bounds
    r = new.rect(
        math.min( r.l + b.l, r.r ),
        math.min( r.t + b.t, r.b ),
        math.min( r.l + b.r, r.r ),
        math.min( r.t + b.b, r.b )
    )
    context:setRect( r )
    context:setTranslate( new.point( r.l, r.t ) )
    
    --Do panel-specific rendering
    self:draw( context )
    
    --Draw children in a similar fashion
    for k,v in ipairs( self.children ) do
        v:drawAll( context )
    end
    
    --Pop the state to restore it to what it once was that we're done drawing this panel and its children
    context:popState()
end

class.register( "panel", c )