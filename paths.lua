--A basic path class implementation follows.
local pathmt = {}
local pathfn = {}

TYPE_ABSOLUTE   = 0 --absolute path (begins with "/"),
TYPE_RELATIVE   = 1 --relative to the 'current' directory (begins with "./" or "../" ),
TYPE_SEARCHPATH = 2 --relative to a search directory (doesn't begin with /, ./, or ../)

--Creates a new path with the given parts and type
local function newPath( parts, type )
    local t = {
        path  = nil,
        parts = parts,
        type  = type
    }

    setmetatable( t, pathmt )
    return t
end

--Creates a path object from a path string
function get( path )
    local parts    = {}
    local pathType = nil

    --Determine what type of path we are
    if string.sub( path, 1, 1 ) == "/" then
        pathType = TYPE_ABSOLUTE
    elseif string.sub( path, 1, 2 ) == "./" or string.sub( path, 1, 3 ) == "../" then
        pathType = TYPE_RELATIVE
    else
        pathType = TYPE_SEARCHPATH
    end

    while path ~= "" do
        --Find the next /
        local i = string.find( path, "/" )

        --This is the last part
        if i == nil then
            i = #path + 1
        end

        --Remove this part from the path, then...
        local part = string.sub( path, 1, i - 1 )
              path = string.sub( path, i + 1 )

        --If we encounter ".." then we remove the previous part.
        --If there was no previous part, or the previous part was ".." as well, then we add ".." to the end of the parts list.
        --If this path is absolute, no parts means it's the root directory
        if part == ".." then
            local c = #parts
            if c == 0 then
                if pathType == TYPE_ABSOLUTE then
                    error( "Invalid path; root directory has no parent directory.", 2 )
                else
                    table.insert( parts, ".." )
                end
            elseif parts[ c ] == ".." then
                table.insert( parts, ".." )
            else
                table.remove( parts )
            end

        --"" and "." are discarded
        elseif part == "." or part == "" then

        --Everything else gets added to the ends of the parts list
        else
            table.insert( parts, part )
        end
    end

    return newPath( parts, pathType )
end

--Converts the path to a string
function pathfn:toString()
    if self.path then return self.path end
    
    --Build a path string from its parts.
    --Depending on what type of path it is, we may prepend "/", "./" or "../".
    local parts = self.parts
    local path
    if     self.type == TYPE_ABSOLUTE then      path = "/"..parts[1]
    elseif self.type == TYPE_RELATIVE then
        if parts[1] == ".." then                path = parts[1]
        else                                    path = "./"..parts[1]
        end
    elseif self.type == TYPE_SEARCHPATH then    path = parts[1]
    else                                        return ""
    end

    for i=2, #parts do
        path = path.."/"..parts[i]
    end

    --Memoize this so we don't have to compute it multiple times
    self.path = path
    return path
end

function pathfn:append( part )
    local parts = self.parts

    if part == "." then
        return
    elseif part == ".." then
        local c = #parts
        if c == 0 then
            if self.type == TYPE_ABSOLUTE then
                error( "Invalid path; root directory has no parent directory." )
            else
                if self.type == TYPE_SEARCHPATH then self.type = TYPE_RELATIVE end
                table.insert( parts, ".." )
            end
        elseif parts[c] == ".." then
            table.insert( parts, ".." )
        else
            table.remove( parts )
        end
    else
        table.insert( parts, part )
    end

    --Reset pathstring
    self.path = nil
end

--Join this path and the given path; e.g. "/this/path" + "other/path" = "/this/path/other/path"
function pathfn:join( other )
    --The other path is an absolute path, it can't be appended to our existing path.
    if other.type == TYPE_ABSOLUTE then return other end

    local parts = {}
    local newType = self.type
    for i,v in ipairs( self.parts  ) do table.insert( parts, v ) end
    for i,v in ipairs( other.parts ) do
        if v == ".." then
            local c = #parts
            if c == 0 then
                if self.type == TYPE_ABSOLUTE then
                    error( "Invalid path; root directory has no parent directory." )
                else
                    if newType == TYPE_SEARCHPATH then newType = TYPE_RELATIVE end
                    table.insert( parts, ".." )
                end
            elseif parts[ c ] == ".." then
                table.insert( parts, ".." )
            else
                table.remove( parts )
            end
        else
            table.insert( parts, v )
        end
        
    end

    return newPath( parts, newType )
end

--Returns the name of the file or directory at that path as a string
function pathfn:getFileName()
    return self.parts[ #self.parts ] or ""
end

--Returns the parent directory as a path object
function pathfn:getParent()
    local parts = {}
    for i = 1, #self.parts - 1 do table.insert( parts, self.parts[ i ] ) end
    return newPath( parts, self.type )
end

--Returns true if this path exists
function pathfn:exists()
    return fs.exists( self:toString() )
end

--Returns true if this path exists and is a file
function pathfn:isFile()
    --Annoying! CC has an fs.isDir() but no fs.isFile()!
    local str = self:toString()
    return fs.exists( str ) and not fs.isDir( str )
end

--Returns true if this path exists and is a directory
function pathfn:isDir()
    return fs.isDir( self:toString() )
end

--You can get individual parts of a path by providing a numerical index.
--Non-numerical keys look up functions in pathfn
function pathmt:__index( k )
    if type( k ) == "number" then return self.parts[ k ] end
    return pathfn[ k ]
end

--Determines whether two paths are equal or not.
function pathmt:__eq( other )
    if type( other )       ~= "table"          then return false end    --Both objects must be tables,
    if self.type           ~= other.type       then return false end    --have matching path entries,
    if type( other.parts ) ~= "table"          then return false end    --have a "parts" table,
    local c = #self.parts
    if c ~= #other.parts                       then return false end    --and have the same number of parts,

    
    for i = 0, c do
        if self.parts[ i ] ~= other.parts[ i ] then return false end    --and corresponding parts must be the same.
    end
    return true
end

--You can join two path together by doing path1..path2
pathmt.__concat   = pathfn.join

--You can convert a path to a string with tostring( path )
pathmt.__tostring = pathfn.toString