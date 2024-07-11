--[[
	* TAS - 'Slowbug Fix Generator' Addon by chris1384 @2024 (youtube.com/chris1384)
	* Have fun mapping! - chris1384 <3
]]

local selectionKey = "b"
local doAllFixes = true -- include position and rotation fixes

addEventHandler("onClientResourceStart", resourceRoot, function()

	if not getResourceFromName("tas") then
		prompt("SF $$failed ##to start. Enable $$'tas' ##resource then restart this one.")
		prompt("Download latest: $$https://github.com/chris1384/mta-tas-dm")
		return
	end

	prompt("")
	prompt("Slowbug Fix Generator has started!")
	prompt("Press $$'"..selectionKey:upper().."' ##to generate the script on a $$TAS ##waypoint in $$Editor##.")
	--prompt("Have fun legend! $$<3 ##- #FFAAFFchris1384")

	bindKey(selectionKey, "down", generateSFScript)
	
end)

function generateSFScript(data)

	local data = exports.tas:getTASData("var").editor_select
	local pos = string.format("%s, %s, %s", data.p[1], data.p[2], data.p[3])
	local rot = string.format("%s, %s, %s", data.r[1], data.r[2], data.r[3])
	local vel = string.format("%s, %s, %s", data.v[1], data.v[2], data.v[3])
	local rvel = string.format("%s, %s, %s", data.rv[1], data.rv[2], data.rv[3])
	
	local posRotLines = [[			setElementPosition(v, ]] .. pos .. [[)
			setElementRotation(v, ]] .. rot .. [[)
]]

	local script = [[
addEventHandler("onClientMarkerHit", createMarker(]] .. pos .. [[, "corona", 3, 0, 13, 84, 0), function(e, d)
	if e == localPlayer and d then
		local v = getPedOccupiedVehicle(e)
		if v and getVehicleController(v) == e then
]]
	.. ((doAllFixes == true and posRotLines) or "") ..
[[
			setElementVelocity(v, ]] .. vel .. [[)
			setElementAngularVelocity(v, ]] .. rvel .. [[0)
		end
	end
end)]] -- you can't do better than this

	setClipboard(script)
	prompt("The slowfix script has been $$copied ##to your $$clipboard##!")

end

-- // TAS Prompts
function prompt(text, r, g, b)
	if type(text) ~= "string" then return end
	local r, g, b = r or 255, g or 100, b or 100
	local prefix = (text ~= "" and "[SF] ") or ""
	return outputChatBox(prefix.."#FFFFFF"..string.gsub(string.gsub(text, "%#%#", "#FFFFFF"), "%$%$", string.format("#%.2X%.2X%.2X", r, g, b)), r, g, b, true)
end