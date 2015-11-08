require( "math2.vector" )

EAST  = 0
NORTH = 1
WEST  = 2
SOUTH = 3
UP    = 4
DOWN  = 5

local dirMap = {
    [EAST ] = vector.EAST,
    [NORTH] = vector.NORTH,
    [WEST ] = vector.WEST,
    [SOUTH] = vector.SOUTH,
    [UP]    = vector.UP,
    [DOWN]  = vector.DOWN
}

function toVector( direction )
    return dirMap[ direction ]
end

function left( direction )
    --UP / DOWN just returns UP / DOWN
    if direction > SOUTH then
        return direction
    end
    
    return (direction + 1) % 4
end

function right( direction )
    --UP / DOWN just returns UP / DOWN
    if direction > SOUTH then
        return direction
    end
    
    return (direction - 1) % 4
end

function back( direction )
    --UP / DOWN just returns UP / DOWN
    if direction > SOUTH then
        return direction
    end
    
    return (direction + 2) % 4
end