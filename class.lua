--Class info is stored here
local classes = {}

--Constructors for classes are stored here allowing you to instantiate classes doing "new.panel()" for instance
_G.new = {}

local function makeMergeTable( classInfo )
    local merged = {}
    local parent = classInfo.parent
    
    --Add the parent's merge table to the new merge table
    if parent ~= nil then
        for k,v in pairs( parent.merged ) do
            merged[k] = v
        end
        merged.base = parent.merged
    end
    
    --Add the class table to the new merge table
    for k,v in pairs( classInfo.raw ) do
        merged[k] = v
    end
    
    --Set / update the merge table
    classInfo.merged = merged
    
    --Set metamethods to values with corresponding keys in the merge table.
    local meta = classInfo.meta
    meta[ "__index"     ] = merged[ "__index"     ]
    meta[ "__newindex"  ] = merged[ "__newindex"  ]
    meta[ "__call"      ] = merged[ "__call"      ]
    meta[ "__tostring"  ] = merged[ "__tostring"  ]
    meta[ "__add"       ] = merged[ "__add"       ]
    meta[ "__sub"       ] = merged[ "__sub"       ]
    meta[ "__mul"       ] = merged[ "__mul"       ]
    meta[ "__div"       ] = merged[ "__div"       ]
    meta[ "__pow"       ] = merged[ "__pow"       ]
    meta[ "__mod"       ] = merged[ "__mod"       ]
    meta[ "__unm"       ] = merged[ "__unm"       ]
    meta[ "__len"       ] = merged[ "__len"       ]
    meta[ "__concat"    ] = merged[ "__concat"    ]
    meta[ "__eq"        ] = merged[ "__eq"        ]
    meta[ "__lt"        ] = merged[ "__lt"        ]
    meta[ "__le"        ] = merged[ "__le"        ]
    meta[ "__metatable" ] = merged[ "__metatable" ]
    --Note: __gc and __mode metamethods are not supported
    
    --If no index override is provided, as is the case most of the time,
    --default the index to the merge table for the class
    if meta[ "__index" ] == nil then
        meta[ "__index" ] = merged
    end
    
    --Update the merge table for child classes
    for k,v in pairs( classInfo.children ) do
        makeMergeTable( k )
    end
end

function register( className, classTable, parentName )
    local classInfo = classes[ className ]
    
    --If the name of a parent class was given, find the class, fail if it's not registered
    local parent
    if parentName ~= nil then
        parent = classes[ parentName ]
        if parent == nil then
            error( string.format( "Cannot register \"%s\", parent class \"%s\" is not registered.", className, parentName ) )
        end
    end
    
    --If the class hasn't been registered yet, do that now
    if classInfo == nil then
        local meta = {}
        classInfo = {
            ["name"]     = className,
            ["raw"]      = classTable,  --Table containing only methods/static members/etc from this class
            ["meta"]     = meta,        --Metatable assigned to objects of this class.
            ["parent"]   = parent,      --Parent class.
            ["children"] = {}           --Child classes. If the parent class reloads, the children need to have their merged table regenerated.
        }
        classes[ className ] = classInfo
        
        --Add the class as a child of the parent class (if any)
        if parent ~= nil then
            parent.children[ classInfo ] = true
        end
        
        --Register a factory for the class in "new"
        _G.new[ className ] = function( ... )
            local t = {}
            setmetatable( t, meta )
            if type( t.init ) == "function" then
                t:init( ... )
            end
            return t
        end
        
    --Otherwise, update the existing table
    else
        classInfo.raw = classTable
        
        local oldparent = classInfo.parent
        if oldparent ~= parent then
            --Remove this class from the old parent
            if oldparent ~= nil then
                oldparent.children[ classInfo ] = nil
            end
            
            --Add this class to the new parent
            if parent ~= nil then
                parent.children[ classInfo ] = true
            end
        end
        
        --Update the class's parent
        classInfo.parent = parent 
    end
    
    --Generate a new "merged" table from the class table + the merge table of its parent (if any)
    --This will also update the merge table of any child classes since they are dependent upon the merge table of their parent class
    makeMergeTable( classInfo )
end

--Unregisters a registered class
function unregister( className )
    local classInfo = classes[ className ]
    
    --Can't unregister a class that doesn't exist
    if classInfo == nil then
        error( string.format( "Cannot unregister class \"%s\", class is not registered.", className ) )
    end
    
    --Can't unregister a class if it has children
    if pairs(classInfo.children)() ~= nil then
        error( string.format( "Cannot unregister class \"%s\", class has dependent child classes registered." ) )
    end
    
    --Existing instances become invalid and cannot access class methods / static members / etc
    classInfo.meta["__index"] = nil
    
    --Unregister the class
    classes[ className ] = nil
    _G.new[ className ] = nil
end