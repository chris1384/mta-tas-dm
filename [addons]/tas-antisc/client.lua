--[[
	* TAS - 'Anti Shortcut Script Generator' Addon by chris1384 @2024 (youtube.com/chris1384)
	* Have fun mapping! - chris1384 <3
]]

-- // EDITABLE HERE
-- // EDITABLE HERE
-- // EDITABLE HERE

local selectionKey = "m" -- this is shown on startup
local antiScType = "rotation" -- this is shown on startup
local rotation_precision = 30 -- this is shown on startup

local markerSize = 8 -- default marker size
local markerAlpha = 100 -- default marker alpha

local generateMarkerVariable = true

--[[
	-- either generate this (true):
	
	local marker1 = createMarker(...) -- description
	addEventHandler(...)
	
	-- OR (false)
	
	addEventHandler("onClientMarkerHit", ...)
	
	-- if set to true, you would need to change marker variable name, itself and in the event
	-- your choice
]]

local payloadScript = "blowVehicle(v)"

--[[
	'v' is the localPlayer vehicle
	to add your own payloads, learn to script (fr) OR replace that string from above with one from this list:
	
	"blowVehicle(v)"
	"setElementHealth(localPlayer, 0)"
	"setElementVelocity(v, 0, 0, 0) setElementPosition(v, 2940.2746, -2051.7504, 3.1619) setElementAngularVelocity(v, 0, 0, 0) setElementRotation(v, 180, 0, 90)"
]]



-- // ALRIGHT YOU'RE DONE HERE
-- // ALRIGHT YOU'RE DONE HERE
-- // ALRIGHT YOU'RE DONE HERE


-- //
-- //
-- //


-- // FROM THIS POINT, DON'T TOUCH ANYTHING!!!
-- // FROM THIS POINT, DON'T TOUCH ANYTHING!!!
-- // FROM THIS POINT, DON'T TOUCH ANYTHING!!!

local isTesting = false
local workingDimension = 200 -- default from editor_main

local previewMarker = nil -- preview marker
local markerCount = 1 -- exported variable marker count
local tas
local selector = nil
local firstTime = true -- seexooooooooooo (prints the useful stuff)

addEventHandler("onClientResourceStart", resourceRoot, function()

	if not getResourceFromName("tas") then
		prompt("Anti-Sc $$failed ##to start. Enable $$'tas' ##resource then restart this one.")
		prompt("Download: $$https://github.com/chris1384/mta-tas-dm")
		return
	end

	prompt("")
	prompt("Press $$'M' ##to create a marker on a $$TAS ##waypoint in $$Editor##.")
	prompt("Do $$/antisc ##to switch between $$'rotation'##, $$'anti-fw' ##or $$'anti-bw' ##anti-scs. You need to create another marker to apply.")
	--prompt("Do $$/antisc ##to switch between $$'rotation' ##or $$'anti-bw' ##anti-scs. Current mode is: $$'"..antiScType.."'")
	prompt("To edit precision of rotation anti-sc, use $$/precision [nr]")
	prompt("Lower values mean $$stricter ##rotation precision. Default is $$"..tostring(rotation_precision).."##.")
	prompt("Have fun legend! $$<3 ##- #FFAAFFchris1384")
	
	bindKey(selectionKey, "down", waypointSelector)
	addCommandHandler("antisc", antiScHandler)
	addCommandHandler("exportantisc", antiScHandler)
	addCommandHandler("precision", antiScHandler)
	
	if getResourceFromName("editor_main") then
		workingDimension = exports["editor_main"]:getWorkingDimension() or 200
		isTesting = getElementDimension(localPlayer) == 0
	end
	
end)

function waypointSelector()

	if isTesting then
		prompt("You can't use anti-sc preview in testing!")
		return
	end

	if previewMarker then
		removeEventHandler("onClientMarkerHit", previewMarker.marker, previewMarker.func)
		destroyElement(previewMarker.marker)
		previewMarker = nil
	end
			
	tas = exports.tas:getTASData() -- heavy function 'l2p'
	if tas then
		if tas.var.editor_select then
		
			selector = tas.var.editor_select
			
			local x, y, z = unpack(selector.p)
			local marqer = createMarker(x, y, z, "corona", markerSize, 255, 0, 0, 100)
			setElementID(marqer, "[anti-sc preview]")
			setElementDimension(marqer, workingDimension)
			
			local funq = function(e, d) 
				if e == localPlayer and d then
					local v = getPedOccupiedVehicle(e)
					if v and getVehicleController(v) == e then
						if (antiScType == "rotation" and not (is_within_tolerance(direction_vector(getElementRotation(v)), direction_vector(unpack(selector.r)), rotation_precision))) or (antiScType == "anti-fw" and not isBackwards(v)) or (antiScType == "anti-bw" and isBackwards(v)) then
							-- no, we don't want to do insta-kill payloads, that shit is nasty in editor
							setElementVelocity(v, 0, 0, 0) 
							setElementPosition(v, 2940.2746, -2051.7504, 3.1619) 
							setElementAngularVelocity(v, 0, 0, 0) 
							setElementRotation(v, 180, 0, 90)
						end
					end
				end
			end
			
			addEventHandler("onClientMarkerHit", marqer, funq)
			
			previewMarker = {marker = marqer, func = funq}

			prompt("The $$'"..antiScType.."' ##preview marker is created! $$Test ##it first then export using $$/exportantisc##!", 255, 150, 255)
		else
			prompt("Waypoint $$failed ##to be selected!")
			return
		end
	end
end

function antiScHandler(cmd, precision)

	if cmd =="precision" then
		local precisionNumber = tonumber(precision)
		if precisionNumber then
			if not (rotation_precision > 0) then 
				prompt("Rotation precision cannot be lower than 0!")
				return 
			end
			rotation_precision = precisionNumber
			prompt("Precision rotation has been modified to: $$"..tostring(rotation_precision))
		else
			prompt("ERROR, precision rotation $$must ##be a number. Current value: $$"..tostring(rotation_precision))
		end
		
	elseif cmd == "antisc" then
	
		if antiScType == "rotation" then
			antiScType = "anti-fw"
		elseif antiScType == "anti-fw" then
			--antiScType = "rotation"
			antiScType = "anti-bw"
		elseif antiScType == "anti-bw" then
			antiScType = "rotation"
		else
			antiScType = "rotation" -- rollback
		end
		
		if previewMarker then
		
			removeEventHandler("onClientMarkerHit", previewMarker.marker, funq)

			local funq = function(e, d) 
				if e == localPlayer and d then
					local v = getPedOccupiedVehicle(e)
					if v and getVehicleController(v) == e then
						if (antiScType == "rotation" and not (is_within_tolerance(direction_vector(getElementRotation(v)), direction_vector(unpack(selector.r)), rotation_precision))) or (antiScType == "anti-fw" and not isBackwards(v)) or (antiScType == "anti-bw" and isBackwards(v)) then
							-- no, we don't want to do insta-kill payloads, that shit is nasty in editor
							setElementVelocity(v, 0, 0, 0) 
							setElementPosition(v, 2940.2746, -2051.7504, 3.1619) 
							setElementAngularVelocity(v, 0, 0, 0) 
							setElementRotation(v, 180, 0, 90)
						end
					end
				end
			end
			
			addEventHandler("onClientMarkerHit", previewMarker.marker, funq)
			
			previewMarker.func = funq
		end
		
		
		prompt("Changed anti-sc type to: $$"..antiScType)
	
		
	elseif cmd == "exportantisc" then
		local generatedScript, reason = generateAntiScScript(antiScType)
		if generatedScript and type(generatedScript) == "string" then
			setClipboard(generatedScript)
			prompt("The $$'"..antiScType.."' ##script $$#"..tostring(markerCount).." ##has been $$copied ##to clipboard! Now $$paste ##it in your map anti-sc script file!", 0, 255, 0)
			if firstTime then
				prompt("Since this is the first export, useful functions have been copied as well.", 255, 255, 0)
				prompt("To skip them, do $$/exportantisc ##again!", 255, 255, 0)
			end
			markerCount = markerCount + 1
			firstTime = false
		else
			if reason then
				prompt("Generating script $$failed ##for reason: "..reason)
			end
		end
		
	end
	
end

function generateAntiScScript(scriptType)

	if not (selector and type(selector) == "table") then return false, "Selector not applied." end -- you didn't even started yet
	if not (selector.p and selector.r) then return false, "Script couldn't get the data from TAS" end -- wow it's my fault then
	if not (rotation_precision > 0) then return false, "Rotation precision is invalid" end -- what an idiot you would be

	-- what the fuck is this?
	
	local firstTimeIsBackwards = ((firstTime == true and (scriptType == "anti-fw" or scriptType == "anti-bw")) and "\n\n\n\n\n\nfunction isBackwards(vehicle)\n	local m = getElementMatrix(vehicle)\n	local x, y, z = getElementVelocity(vehicle)\n	local d = (x * m[2][1]) + (y * m[2][2]) + (z * m[2][3])\n	return d < 0\nend") or ""
	
	local firstTimeRotationAntiSc = (firstTime == true and scriptType == "rotation" and function() local file = fileOpen("rotation-antisc.lua") local data = fileRead(file, fileGetSize(file)) fileClose(file) return "\n\n\n\n\n\n"..data end) or ""
	local firstTimeRotationCode = (type(firstTimeRotationAntiSc) == "function" and firstTimeRotationAntiSc()) or ""
	
	local firstTimeIntroComment = (firstTime == true and "-- //\n-- // MARKERS ANTI-SC\n-- //\n\n") or ""
	local firstTimePasteComment = (firstTime == true and "\n\n-- now place new markers under this spot") or ""

	local payloadCondition = (scriptType == "rotation" and "not (is_within_tolerance(direction_vector(getElementRotation(v)), direction_vector("..tostring(float(selector.r[1]))..", "..tostring(float(selector.r[2]))..", "..tostring(float(selector.r[3])).."), ".. tostring(rotation_precision).."))") or (scriptType == "anti-fw" and "not (isBackwards(v))") or (scriptType == "anti-bw" and "(isBackwards(v))") or "true" -- rollback, trigger everytime the marker is touched (why? idk u tell me)
	
	local markerPosition = tostring(float(selector.p[1]))..", "..tostring(float(selector.p[2]))..", "..tostring(float(selector.p[3]))
	local markerVariable = 'createMarker('..markerPosition..', "corona", '..tostring(markerSize)..', 255, 0, 0, '..tostring(markerAlpha)..')'
	if generateMarkerVariable then
		markerVariable = "local marker"..tostring(markerCount).." = " .. markerVariable .. " -- this is an anti-sc marker\n\n"
	end
	
	local inEventVariable = (generateMarkerVariable == true and "marker"..tostring(markerCount)) or markerVariable
	if not generateMarkerVariable then
		markerVariable = ""
	end
	
	-- Our final script. Take a look at it, praise as yours, go tell everyone you made it. Unbeknownst to them, it was generated using this addon. :D 
	
	local script = firstTimeIntroComment .. markerVariable .. [[
addEventHandler("onClientMarkerHit", ]] .. inEventVariable .. [[, function(e, d)
	if e == localPlayer and d then
		local v = getPedOccupiedVehicle(e)
		if v and getVehicleController(v) == e then
			if ]] .. payloadCondition .. [[ then
				]] .. payloadScript .. "\n" .. [[
			end
		end
	end
end)]] .. firstTimePasteComment .. firstTimeIsBackwards .. firstTimeRotationCode

	return script
end

function editorEvents()
	if not previewMarker then return end
	if not (previewMarker.marker and isElement(previewMarker.marker)) then return end
	
	if eventName == "onEditorSuspended" then
		setElementDimension(previewMarker.marker, 0)
		isTesting = true
		
	elseif eventName == "onEditorResumed" then
		setElementDimension(previewMarker.marker, workingDimension)
		isTesting = false
	end
end
for _,editorEventsList in ipairs({"onEditorSuspended", "onEditorResumed"}) do
	addEvent(editorEventsList)
	addEventHandler(editorEventsList, root, editorEvents)
end

function clickEvents(key, state)
	if isTesting then return end
	if key == "mouse1" or key == "mouse2" then
		if state then
			setElementDimension(previewMarker.marker, 1384)
		else
			setTimer(function()
				if isTesting then return end
				if previewMarker then
					setElementDimension(previewMarker.marker, getElementDimension(localPlayer)) -- you could be in testing or map editing
				end
			end, 50, 1)
		end
	end
end
addEventHandler("onClientKey", root, clickEvents)

-- unused
--[[
addEventHandler("onClientRender", root, function()
	if selector and type(selector) == "table" then
		local x, y, z = unpack(selector.p)
		dxDrawLine3D(x, y, z-5, x, y, z+5, 0xFFFF6464, 20)
	end
end)
]]

function isBackwards(vehicle)
	local m = getElementMatrix(vehicle)
	local x, y, z = getElementVelocity(vehicle)
	local d = (x * m[2][1]) + (y * m[2][2]) + (z * m[2][3])
	return d < 0
end
	
-- // TAS Prompts
function prompt(text, r, g, b)
	if type(text) ~= "string" then return end
	local r, g, b = r or 255, g or 100, b or 100
	local prefix = (text ~= "" and "[TAS] ") or ""
	return outputChatBox(prefix.."#FFFFFF"..string.gsub(string.gsub(text, "%#%#", "#FFFFFF"), "%$%$", string.format("#%.2X%.2X%.2X", r, g, b)), r, g, b, true)
end

-- // Used for efficient saving
function float(number)
	return math.floor( number * 1000 ) * 0.001
end