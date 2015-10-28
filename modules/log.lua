local logTerminal

--Sets a terminal to log to.
function set( terminal )
    logTerminal = terminal
end

--Return our current log terminal.
function get( terminal )
    return logTerminal
end

--This must be called by a program running on the tab you want to redirect output to.
--print(), write(), io.write(), term.write(), etc. will go to this terminal instead.
function redirect()
    return term.redirect( logTerminal )
end