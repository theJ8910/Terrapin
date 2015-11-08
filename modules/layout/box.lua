--TODO R2L and B2T orders
require( "math2.rect" )
require( "util" )

--boxLayout
local c = {}

--Valid orders
L2R = 0  --Left-to-right
R2L = 1  --Right-to-left
T2B = 2  --Top-to-bottom
B2T = 3  --Bottom-to-top

--mins is a table of minimum sizes.
--maxs is a table of maximum sizes.
--mins and maxs are expected to have the same number of elements (lets call this n).
--For every i between 1 and n, mins[i] is expected to be less than or equal to maxs[i].
--available is the total amount of space the container has available on the axis of interest.
--reverse should be true if you want offsets in the opposite direction of the axis of interest (i.e. right-to-left or bottom-to-top).
--Returns two tables: sizes, offsets. Both are arrays between 1 and n.
--    sizes[i] contains the size (width or height) that component i should be.
--    offset[i] contains the offset (x or y) that component i should be at, where 0 represents
--    right at the start (which will be left, top, right, or bottom depending on chosen alignment).
local function getOffsetsAndSizes( mins, maxs, available, reverse )
    local n = #mins

    --Note: "width", "height", "length" are all terms that describe how small or large something on a particular axis is.
    --We use the term "size" here so as to not associate it with any particular axis
    local offsets = {}
    local sizes   = {}

    --Sum mins, and count how many huge maxs we've got.
    local minsTotal = 0
    local huges     = 0
    for i = 1, n do
        minsTotal = minsTotal + mins[ i ]
        if maxs[i] == math.huge then huges = huges + 1 end
    end

    local currentOffset = 0
    local size
    --The total of all the minimums is greater than the available space.
    --All sizes will be minimums. The box will overflow.
    if minsTotal >= available then
        for i = 1, n do
            size          = mins[ i ]

            sizes[ i ]    = size
            offsets[ i ]  = currentOffset
            currentOffset = currentOffset + size
        end
    --We've got room to work with.
    --If any maxs are math.huge (infinity), all other sizes will use their minimums, and the remaining space will be evenly split between the math.huge sizes.
    elseif huges > 0 then
        local spaceToFill = available - minsTotal
        local hugeSize    = math.floor( spaceToFill / huges )
        local size
        for i = 1, n do
            if maxs[i] == math.huge then size = mins[ i ] + hugeSize
            else                         size = mins[ i ]
            end

            sizes[ i ]    = size
            offsets[ i ]  = currentOffset
            currentOffset = currentOffset + size
        end
    --We've got room to work with.
    --In order to fill the remaining space, either:
    --    A. Make every component use its maximum (maxsTotal <= available)
    --    B. Linearly interpolate each size between it's minimum and maximum by a constant %, such that the remaining space is perfectly filled.
    else
        --Sum maxs. None of them are math.huge.
        local maxsTotal = 0
        for i = 1, n do
            maxsTotal = maxsTotal + maxs[ i ]
        end

        local sizeDiff    = maxsTotal - minsTotal
        local spaceToFill = math.min( available - minsTotal, sizeDiff )

        --Determine how much we need to scale each component.
        --We calculate this by getting the ratio between the amount of space to fill and the size difference.
        local f           = ( sizeDiff == 0 ) and 0 or ( spaceToFill / sizeDiff )

        for i = 1, n do
            size          = mins[ i ] + math.floor( f * ( maxs[ i ] - mins[ i ] ) )

            sizes[ i ]    = size
            offsets[ i ]  = currentOffset
            currentOffset = currentOffset + size
        end
    end

    return offsets, sizes
end

--Layout children in a horizontal (L2R or R2L) order
local function layoutHorizontal( target, reverse )
    --Grab min and max widths
    local mins = {}
    local maxs = {}

    --Calculate min/max widths for each panel, including padding
    local padding, paddingTotal, sizeRange
    for i,v in ipairs( target.children ) do
        if v:getVisible() then
            padding = v:getPadding()
            paddingTotal = padding.l + padding.r
            sizeRange = v:getSizeRange()
            mins[ i ] = sizeRange.minW + paddingTotal
            maxs[ i ] = sizeRange.maxW + paddingTotal
        else
            mins[i] = 0
            maxs[i] = 0
        end
    end

    --Calculate where the first component will be positioned within the container
    local margins = target:getMargins()
    local beginX = margins.l
    local beginY = margins.t

    --Subtract margins from the space we have available to lay out
    local b = target:getBounds()
    local width  = b:getWidth()  - ( beginX + margins.r )
    local height = b:getHeight() - ( beginY + margins.b )

    --Determine offsets and widths for the panels
    local offsets, widths = getOffsetsAndSizes( mins, maxs, width, reverse )

    --Position and layout the children
    for i,v in ipairs( target.children ) do
        if v:getVisible() then
            local x = beginX + offsets[i]
            padding   = v:getPadding()
            sizeRange = v:getSizeRange()
            local r = new.rect(
                x,
                beginY,
                x      + widths[i] - ( padding.l + padding.r ),
                beginY + util.clamp( height - ( padding.t + padding.b ), sizeRange.minH, sizeRange.maxH )
            )

            v:setBounds( r )
            v:layout()
        end
    end
end

--Layout children in a vertical (T2B or B2T) order
local function layoutVertical( target, reverse )
    --Grab min and max heights
    local mins = {}
    local maxs = {}

    --Calculate min/max height for each panel, including padding
    local padding, paddingTotal, sizeRange
    for i,v in ipairs( target.children ) do
        if v:getVisible() then
            padding = v:getPadding()
            paddingTotal = padding.t + padding.b
            sizeRange = v:getSizeRange()
            mins[ i ] = sizeRange.minH + paddingTotal
            maxs[ i ] = sizeRange.maxH + paddingTotal
        else
            mins[ i ] = 0
            maxs[ i ] = 0
        end
    end

    --Calculate where the first component will be positioned within the container
    local margins = target:getMargins()
    local beginX  = margins.l
    local beginY  = margins.t

    --Subtract margins from the space we have available to lay out
    local b = target:getBounds()
    local width  = b:getWidth()  - ( beginX + margins.r )
    local height = b:getHeight() - ( beginY + margins.b )

    --Determine offsets and heights for the panels
    local offsets, heights = getOffsetsAndSizes( mins, maxs, height, reverse )

    --Position and layout the children
    for i,v in ipairs( target.children ) do
        if v:getVisible() then
            local y = beginY + offsets[i]
            padding = v:getPadding()
            sizeRange = v:getSizeRange()
            local r = new.rect(
                beginX,
                y,
                beginX + util.clamp( width - ( padding.l + padding.r ), sizeRange.minW, sizeRange.maxW ),
                y      + heights[i] - ( padding.t + padding.b )
            )

            v:setBounds( r )
            v:layout()
        end
    end
end

--Order should be one of:
--    box.L2R
--    box.R2L
--    box.T2B
--    box.B2T
function c:init( order )
    self.order = order
end

--This is called to lay out target.
function c:__call( target )
    if     self.order == L2R then return layoutHorizontal( target, false )
    elseif self.order == R2L then return layoutHorizontal( target, true  )
    elseif self.order == T2B then return layoutVertical(   target, false )
    elseif self.order == B2T then return layoutVertical(   target, true  )
    else                          return nil
    end
end

--Sets the layout order.
function c:setOrder( order )
    self.order = order
end

--Returns the layout order.
function c:getOrder()
    return self.order
end

class.register( "boxLayout", c )