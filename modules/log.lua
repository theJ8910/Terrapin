local logTerminal

--Sets a target for logging
function set( terminal )
    logTerminal = terminal
end

function write( str )
    if logTerminal == nil then return end

    local old = term.redirect( logTerminal )
    print( str )
    term.redirect( old )
end