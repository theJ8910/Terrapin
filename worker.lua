require( "vector" )
require( "orient" )
require( "serialize" )
require( "ids" )

local workerfn = {}
local workermt = { ["__index"] = workerfn }

local workers = {}

--Job types
HAULING      = 0      --Haulers move items from place to place
MINING       = 1      --Miners can mine things
CRAFTING     = 2      --Crafters can make things
SCOUTING     = 3      --Scouts have sonic sensors they can use to detect several blocks at a time 
EXPERT       = 4      --Experts can (attempt to) identify what specific blocks are by comparing their inventory with them
CONSTRUCTION = 5      --Builders can build things

function new()
    local t = {}
    setmetatable( t, workermt )
    
    --Keep track of computer / turtle's current position / facing direction
    t.pos  = vector.new( 0, 0, 0 )
    t.dir  = orient.EAST
    t.jobs = {}
    
    table.insert( workers, t )
    
    return t
end

function getAll()
    return workers
end

function workerfn:setPos( pos )
    self.pos = pos
end

function workerfn:getPos()
    return self.pos
end

function workerfn:setDir( dir )
    self.dir = dir
end

function workerfn:getDir()
    return self.dir
end

function workerfn:addJob( job )
    self.jobs[ job ] = true
end

function workerfn:removeJob( job )
    self.jobs[ job ] = nil
end

function workerfn:getJobs()
    return self.jobs
end

function workerfn:getSerialID()
    return ids.WORKER
end

function workerfn:save( writer )
    writer:writeNumber( self.pos.x )
    writer:writeNumber( self.pos.y )
    writer:writeNumber( self.pos.z )
    
    writer:writeUnsignedInt8( self.dir )
end

function workerfn:load( reader )
    self.pos = vector.new(
        reader:readNumber(),
        reader:readNumber(),
        reader:readNumber()
    )
    
    self.dir = reader:readUnsignedInt8()
end

serialize.register( new, ids.WORKER )