require( "vector" )
require( "orient" )
require( "serialize" )
require( "ids" )
require( "comms" )

local workers = {}

--Job types
HAULING      = 0      --Haulers move items from place to place
MINING       = 1      --Miners can mine things
CRAFTING     = 2      --Crafters can make things
SCOUTING     = 3      --Scouts have sonic sensors they can use to detect several blocks at a time 
EXPERT       = 4      --Experts can (attempt to) identify what specific blocks are by comparing their inventory with them
CONSTRUCTION = 5      --Builders can build things

local c = {}

--Adds a worker with the given ID
function add( id )
    local worker = new.worker( id )

    workers[ id ] = worker

    return worker
end

--Returns a worker with the given ID
function get( id )
    return workers[ id ]
end

--Returns a table
--TODO: this should return a copy and/or immutable view
function getAll()
    return workers
end

function c:init( id )
    --Keep track of computer / turtle's current position / facing direction
    self.id   = id
    self.pos  = new.vector( 0, 0, 0 )
    self.dir  = orient.EAST
    self.jobs = {}
end

--Send a message to this turtle
function c:transmit( msgID, ... )
    comms.transmit( self.id, msgID, ... )
end

function c:setPos( pos )
    self.pos = pos
end

function c:getPos()
    return self.pos
end

function c:setDir( dir )
    self.dir = dir
end

function c:getDir()
    return self.dir
end

function c:addJob( job )
    self.jobs[ job ] = true
end

function c:removeJob( job )
    self.jobs[ job ] = nil
end

function c:getJobs()
    return self.jobs
end

function c:getSerialID()
    return ids.WORKER
end

function c:save( writer )
    writer:writeUnsignedInt32( self.id )
    writer:writeObject( self.pos )
    writer:writeUnsignedInt8( self.dir )
end

function c:load( reader )
    self.id  = reader:readUnsignedInt32()
    self.pos = reader:readObject( ids.VECTOR )
    self.dir = reader:readUnsignedInt8()
end

class.register( "worker", c )

serialize.register( function( serialID ) return new.worker( 0 ) end, ids.WORKER )