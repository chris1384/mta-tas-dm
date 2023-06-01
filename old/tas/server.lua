-- * TAS - Recording Tool by chris1384 @2020

addEvent("onRaceStateChanging")
addEventHandler("onRaceStateChanging", root, function(new)
	if new == "Running" then
		for k,v in ipairs(getElementsByType("player")) do triggerClientEvent(v, "tas:triggerCommand", v, "Started") end
	elseif new == "NoMap" or new == "PostFinish" then
		for k,v in ipairs(getElementsByType("player")) do triggerClientEvent(v, "tas:triggerCommand", v, "Stop") end
	end
end)
