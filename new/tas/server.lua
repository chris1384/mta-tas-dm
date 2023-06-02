--[[
		* TAS - Recording Tool by chris1384 @2020
		* version 1.4
--]]

--[[
addEvent("onRaceStateChanging")
addEventHandler("onRaceStateChanging", root, function(new)
	local everyone = getElementsByType("player")
	if new == "Running" then
		triggerClientEvent(everyone, "tas:triggerCommand", everyone, "Started")
	elseif new == "NoMap" or new == "PostFinish" then
		triggerClientEvent(everyone, "tas:triggerCommand", everyone, "Stop")
	end
end)
]]

addEvent("tas:onModelChange")
addEventHandler("tas:onModelChange", root, function(model)
	local vehicle = source
	setElementModel(vehicle, model)
end)
