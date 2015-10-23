local log = get("log").t
log.set( term.current() )
while true do
    local event, scancode = os.pullEvent( "key" )
    if scancode == 16 then return end
end
