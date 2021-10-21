from_user = event:getHeader("from-user"); 
event_type = argv[1]
freeswitch.consoleLog("info","----------- " .. tostring(event_type) .. " [user_id: " ..from_user.. "]" .. "\n")