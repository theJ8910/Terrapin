--fillLayout lays out children in a container such that it takes up all available space in the container,
--taking spacing (margins, padding ) into consideration of course.
--Mostly intended for containers with a single child; root panels commonly have this layout.
require( "math2.rect" )
require( "util" )

--fillLayout
local c = {}

function c:__call( target )
    --Subtract margins from container's width and height
    local b = target:getBounds()
    local margins = target:getMargins()
    local w = b:getWidth()  - ( margins.l + margins.r )
    local h = b:getHeight() - ( margins.t + margins.b )

    --Position and lay out children
    --Components will fill all available space
    for i,v in ipairs( target.children ) do
        if v:getVisible() then
            local padding = v:getPadding()

            local sizeRange = v:getSizeRange()
            local xOffset = margins.l + padding.l
            local yOffset = margins.t + padding.t
            local r = new.rect(
                xOffset,
                yOffset,
                xOffset + util.clamp( w - ( padding.l + padding.r ), sizeRange.minW, sizeRange.maxW ),
                yOffset + util.clamp( h - ( padding.t + padding.b ), sizeRange.minH, sizeRange.maxH )
            )

            v:setBounds( r )
            v:layout()
        end
    end
end

class.register( "fillLayout", c )