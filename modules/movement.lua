local function simplestep( movefn, dig, digfn )
    if movefn() then             return true
    elseif dig and digfn() then  return movefn()
    else                         return false
    end
end

function west()
    if coords.getdir() == 0 then
        if not turtle.back() then return false end
    else
        face( 2 )
        if not turtle.forward() then return false end
    end
    
    local pos = coords.getpos()
    coords.setpos( coords.v( pos.x - 1, pos.y, pos.z ) )
    
    return true;
end

function east()
    if coords.getdir() == 2 then
        if not turtle.back() then return false end
    else
        face( 0 )
        if not turtle.forward() then return false end
    end
    
    local pos = coords.getpos()
    coords.setpos( coords.v( pos.x + 1, pos.y, pos.z ) )
    
    return true;
end

function north()
    if coords.getdir() == 3 then
        if not turtle.back() then return false end
    else
        face( 1 )
        if not turtle.forward() then return false end
    end
    
    local pos = coords.getpos()
    coords.setpos( coords.v( pos.x, pos.y + 1, pos.z ) )
    
    return true;
end

function south()
    if coords.getdir() == 1 then
        if not turtle.back() then return false end
    else
        face( 3 )
        if not turtle.forward() then return false end
    end
    
    local pos = coords.getpos()
    coords.setpos( coords.v( pos.x, pos.y - 1, pos.z ) )
    
    return true;
end

function up()
    if not turtle.up() then return false end
    
    local pos = coords.getpos()
    coords.setpos( coords.v( pos.x, pos.y, pos.z + 1 ) )
    
    return true;
end

function down()
    if not turtle.down() then return false end
    
    local pos = coords.getpos()
    coords.setpos( coords.v( pos.x, pos.y, pos.z - 1 ) )
    
    return true;
end

function digwest()
    face( 2 )
    return turtle.dig()
end

function digeast()
    face( 0 )
    return turtle.dig()
end

function dignorth()
    face( 1 )
    return turtle.dig()
end

function digsouth()
    face( 3 )
    return turtle.dig()
end

function digup()
    return turtle.digUp()
end

function digdown()
    return turtle.digDown()
end

--simple movement (greedy approach, each step gets you closer to the target)
--can fail if options are exhausted (can't move / if dig is enabled, break blocks to get to the position) 
function simple( targetpos, dig )
    local movefn, digfn
    local pos = coords.getpos()
    while pos.x ~= targetpos.x or
          pos.y ~= targetpos.y or
          pos.z ~= targetpos.z do
        
        if not (
            ( targetpos.x > pos.x and simplestep( east,  dig, digeast  ) ) or
            ( targetpos.x < pos.x and simplestep( west,  dig, digwest  ) ) or
            ( targetpos.y > pos.y and simplestep( north, dig, dignorth ) ) or
            ( targetpos.y < pos.y and simplestep( south, dig, digsouth ) ) or
            ( targetpos.z > pos.z and simplestep( up,    dig, digup    ) ) or
            ( targetpos.z < pos.z and simplestep( down,  dig, digdown  ) )
        ) then
            return false
        end
        
        pos = coords.getpos()
    end
    
    return true
end

local function astarnode( pos, g, f, predecessor )
    return { ["pos"] = pos,
             ["g"] = g,
             ["f"] = f,
             ["predecessor"] = predecessor
           }
end

function astar( targetpos )
    --Starting position + node
    local pos          = coords.getpos()
    local posstr       = coords.vstr( pos )
    local begin_node   = astarnode( pos, 0, coords.manhattan( pos, targetpos ), nil )
    
    --Discovered nodes
    --key is node position's string
    --value is the node data
    local nodedata     = { [posstr] = begin_node }
    
    --Heap of nodes that have been discovered, but not yet processed
    --key is node's f value, value is node position's string
    --Starts off with the beginning node
    local open         = heap.new( heap.lt )
    open:enqueue( begin_node.f, posstr )
    
    --closed nodes are nodes that have been processed
    --key is node position's string
    --value is true
    local closednodes  = {}
    
    local cur_node, pre_node
    local neighborpos = {}
    local tentative_g, search
    
    while open:notempty() do
        cur_node = nodedata[ open:dequeue() ]
        
        --Found goal?
        if coords.vequal( cur_node.pos, targetpos ) then
            
            local path = {}
            pre_node = cur_node.predecessor
            while pre_node ~= nil do
                --Insert the appropriate movement function necessary to get from cur_node to pre_node
                if     cur_node.pos.x > pre_node.pos.x then table.insert( path, east  )
                elseif cur_node.pos.x < pre_node.pos.x then table.insert( path, west  )
                elseif cur_node.pos.y > pre_node.pos.y then table.insert( path, north )
                elseif cur_node.pos.y < pre_node.pos.y then table.insert( path, south )
                elseif cur_node.pos.z > pre_node.pos.z then table.insert( path, up    )
                elseif cur_node.pos.z < pre_node.pos.z then table.insert( path, down  )
                end
                
                cur_node = pre_node
                pre_node = cur_node.predecessor
                
            end
            
            for i=#path, 1, -1 do
                if not simplestep( path[i], false ) then return false end
            end
            return true
        end
        
        --Add this node to the list of closed nodes
        closednodes[ coords.vstr( cur_node.pos ) ] = true
        
        --Add neighbors of this node
        neighborpos[1] = coords.east(  cur_node.pos )
        neighborpos[2] = coords.west(  cur_node.pos )
        neighborpos[3] = coords.north( cur_node.pos )
        neighborpos[4] = coords.south( cur_node.pos )
        neighborpos[5] = coords.up(    cur_node.pos )
        neighborpos[6] = coords.down(  cur_node.pos )
        
        for k, v in ipairs( neighborpos ) do
            posstr = coords.vstr(v)
            
            --We can only move to tiles filled with air
            --Closed nodes are nil
            if map.get(v) == -1 and closednodes[ posstr ] == nil then
                
                search = open:search( posstr )
                tentative_g = cur_node.g + 1
                
                if not search then
                    --The node doesn't exist yet. Lets create it.
                    nodedata[ posstr ] = astarnode( v, tentative_g, tentative_g + coords.manhattan( v, targetpos ), cur_node )
                    
                    --And insert it into the heap
                    open:enqueue( nodedata[ posstr ].f, posstr )
                    
                else
                    --This node is already in the waiting list.
                    --We've found a shorter route to it, so we need to modify it:
                    pre_node = nodedata[open[search]]
                    if tentative_g < pre_node.g then
                        
                        --Remove the previous node from the heap
                        open:remove( posstr )
                        
                        --Modify it's g to use the shorter value (and also it's f since it's dependent upon g)
                        pre_node.g = tentative_g
                        pre_node.f = tentative_g + coords.manhattan( v, targetpos )
                        
                        --A shorter path to this node is achieved by visiting the following node before this one:
                        pre_node.predecessor = cur_node
                        
                        --Reinsert the node in the heap
                        open:enqueue( pre_node.f, posstr )
                        
                    end
                end
            end
            
        end
    end
    
    return false
end

--[[
Facing directions.

  1
2   0
  3
]]--
function face( tdir )
    local offset = (tdir % 4) - coords.getdir()
    if offset > 2 then
        offset = offset - 4
    elseif offset < -2 then
        offset = offset + 4
    end
    while offset > 0 do
        turtle.turnLeft()
        offset = offset - 1
    end
    while offset < 0 do
        turtle.turnRight()
        offset = offset + 1
    end
    coords.setdir( tdir )
    return true
end