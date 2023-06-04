--[[
		* TAS - Recording Tool by chris1384 @2020
		* version 1.4
--]]

-- // Use the event given by the Race Default
addEvent("onRaceStateChanging")
addEventHandler("onRaceStateChanging", root, function(new)

	local everyone = getElementsByType("player")
	
	if new == "Running" then
		triggerClientEvent(everyone, "tas:triggerCommand", resourceRoot, "Started")
	elseif new == "NoMap" or new == "PostFinish" then
		triggerClientEvent(everyone, "tas:triggerCommand", resourceRoot, "Stop")
	end
	
end)

-- // Model Change Resync with clients (might break up)
addEvent("tas:onModelChange", true)
addEventHandler("tas:onModelChange", root, function(model)
	setElementModel(source, model)
end)
