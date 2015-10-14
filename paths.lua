--A basic path class implementation follows.
local pathmt = {}
local pathfn = {}

TYPE_ABSOLUTE   = 0 --absolute path (begins with "/"),
TYPE_RELATIVE   = 1 --relative to the 'current' directory (begins with "./" or "../" ),
TYPE_SEARCHPATH = 2 --relative to a search directory (doesn't begin with /, ./, or ../)

--Creates a new path
local function newPath()
    local t = {
        path  = nil,
        type  = type
    }

    setmetatable( t, pathmt )
    return t
end

--Creates a path object from a path string
function get( str )
    local path = newPath()
    local pathType

    --Determine what type of path we are
    if string.find( str, "^/" ) then
        pathType = TYPE_ABSOLUTE
    elseif string.find( str, "^%.%.?/" ) then
        pathType = TYPE_RELATIVE
    else
        pathType = TYPE_SEARCHPATH
    end

    while str ~= "" do
        --Find the next /
        local i = string.find( str, "/" )

        --This is the last part
        if i == nil then
            i = #str + 1
        end

        --Remove this part from the path, then...
        local part = string.sub( str, 1, i - 1 )
              str  = string.sub( str, i + 1 )

        --If we encounter ".." then we remove the previous part.
        --If there was no previous part, or the previous part was ".." as well, then we add ".." to the end of the path.
        --If this path is absolute, no parts means it's the root directory
        if part == ".." then
            local c = #path
            if c == 0 then
                if type == TYPE_ABSOLUTE then
                    error( "Invalid path; root directory has no parent directory.", 2 )
                else
                    table.insert( path, ".." )
                end
            elseif path[ c ] == ".." then
                table.insert( path, ".." )
            else
                table.remove( path )
            end

        --"" and "." are discarded
        elseif part == "." or part == "" then

        --Everything else gets added to the ends of the path
        else
            table.insert( path, part )
        end
    end

    path.type = pathType
    return path
end

--Converts the path to a string
function pathfn:toString()
    if self.path then return self.path end
    
    --Build a path string from its parts.
    --Depending on what type of path it is, we may prepend "/", "./" or "../".
    local path
    if     self.type == TYPE_ABSOLUTE then      path = "/"..self[1]
    elseif self.type == TYPE_RELATIVE then
        if self[1] == ".." then                 path = self[1]
        else                                    path = "./"..self[1]
        end
    elseif self.type == TYPE_SEARCHPATH then    path = self[1]
    else                                        return ""
    end

    for i=2, #self do
        path = path.."/"..self[i]
    end

    --Memoize this so we don't have to compute it multiple times
    self.path = path
    return path
end

--NOTE: This function is kind of hacky; paths really shouldn't be changed after they're created.
--I'd prefer to have this function in a pathbuilder object that returns the path after we're done appending to it; maybe TODO this later.
function pathfn:append( part )
    if part == "." then
        return
    elseif part == ".." then
        local c = #self
        if c == 0 then
            if self.type == TYPE_ABSOLUTE then
                error( "Invalid path; root directory has no parent directory." )
            else
                if self.type == TYPE_SEARCHPATH then self.type = TYPE_RELATIVE end
                table.insert( self, ".." )
            end
        elseif self[c] == ".." then
            table.insert( self, ".." )
        else
            table.remove( self )
        end
    else
        table.insert( self, part )
    end

    --Reset pathstring
    self.path = nil
end

--Join this path and the given path; e.g. "/this/path" + "other/path" = "/this/path/other/path"
function pathfn:join( other )
    --The other path is an absolute path, it can't be appended to our existing path.
    if other.type == TYPE_ABSOLUTE then return other end

    local path = newPath()
    local newType = self.type
    for i,v in ipairs( self  ) do table.insert( path, v ) end
    for i,v in ipairs( other ) do
        if v == ".." then
            local c = #path
            if c == 0 then
                if newType == TYPE_ABSOLUTE then
                    error( "Invalid path; root directory has no parent directory." )
                else
                    if newType == TYPE_SEARCHPATH then newType = TYPE_RELATIVE end
                    table.insert( path, ".." )
                end
            elseif path[ c ] == ".." then
                table.insert( path, ".." )
            else
                table.remove( path )
            end
        else
            table.insert( path, v )
        end
        
    end

    path.type = newType
    return path
end

--Returns the name of the file or directory at that path as a string
--e.g. for the path "/a/b/c.lua", :getFileName() would return "c.lua"
function pathfn:getFileName()
    return self[ #self ] or ""
end

--Returns the parent directory as a path object
--e.g. for the path "/a/b/c.lua", :getParent() would return "/a/b"
function pathfn:getParent()
    local parent = newPath()
    parent.type = self.type

    for i = 1, #self - 1 do table.insert( parent, self[ i ] ) end
    return parent
end

--Returns true if the file/directory represented by this path exists
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

pathmt.__index = pathfn

--Determines whether two paths are equal or not.
function pathmt:__eq( other )
    if type( other )       ~= "table"          then return false end    --Both objects must be tables,
    if self.type           ~= other.type       then return false end    --be the same type of path (i.e. absolute, relative, or searchpath)
    local c = #self
    if c ~= #other                             then return false end    --have the same number of parts,

    for i = 0, c do
        if self[ i ] ~= other[ i ]             then return false end    --and corresponding parts must be the same.
    end
    return true
end

--You can join two path together by doing path1..path2
pathmt.__concat   = pathfn.join

--You can convert a path to a string with tostring( path )
pathmt.__tostring = pathfn.toString