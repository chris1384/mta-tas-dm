--[[
	* TAS - 'Anti Shortcut Script Generator' Addon by chris1384 @2024 (youtube.com/chris1384)
	* Have fun mapping! - chris1384 <3
]]

-- // EDITABLE HERE
-- // EDITABLE HERE
-- // EDITABLE HERE



local showGuides = true
--[[
	this shows the antisc guides, it will help you understand how the direction vectors work
	every direction vector is locked to a certain axis, for example: 
	
	rotation_axis set to X and rotating on X axis (ARROW UP/DOWN) will not move the line
	rotation_axis set to Y and rotating on Y axis (ARROW LEFT/RIGHT) will not move the line
	rotation_axis set to Z and rotating on Z axis (SPACE + A/D) will not move the line
	
	this is useful to let you move freely on one axis, while the others are being limited
	unfortunately this script only does the X axis by default and it's not recommended for beginners to mess with it.
	to limit the antisc on all 3 axis you need knowledge. :)
]]
	
local selectionKey = "m" -- this is shown on startup
local antiScType = "rotation" -- this is shown on startup

local rotation_axis = "y" -- for advanced users only, can be: "x" , "y" or "z"
local rotation_precision = 30 -- this is shown on startup

local markerR, markerG, markerB = 255, 0, 0 -- default marker color
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
	prompt("Press $$'"..selectionKey:upper().."' ##to create a marker on a $$TAS ##waypoint in $$Editor##.")
	prompt("Do $$/antisc ##to switch between $$'rotation'##, $$'anti-fw' ##or $$'anti-bw' ##anti-scs. You need to create another marker to apply.")
	prompt("To edit precision of rotation anti-sc, use $$/precision [nr]")
	prompt("Lower values mean $$stricter ##rotation precision. Default is $$"..tostring(rotation_precision).."##.")
	prompt("Have fun legend! $$<3 ##- #FFAAFFchris1384")
	
	bindKey(selectionKey, "down", waypointSelector)
	addCommandHandler("antisc", antiScHandler)
	addCommandHandler("exportantisc", antiScHandler)
	addCommandHandler("precision", antiScHandler)
	
	if getResourceFromName("editor_main") then
		workingDimension = exports["editor_main"]:getWorkingDimension() or 200
		--isTesting = getElementDimension(localPlayer) == 0 -- // this would softlock the script
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
			local marqer = createMarker(x, y, z, "corona", markerSize, markerR, markerG, markerB, markerAlpha)
			setElementID(marqer, "[anti-sc preview]")
			setElementDimension(marqer, workingDimension)
			
			local funq = function(e, d) 
				if e == localPlayer and d then
					local v = getPedOccupiedVehicle(e)
					if v and getVehicleController(v) == e then
						local rx, ry, rz = getElementRotation(v)
						local mrx, mry, mrz = unpack(selector.r)
						if (antiScType == "rotation" and not (is_within_tolerance(direction_vector({rx, ry, rz}, rotation_axis), direction_vector({mrx, mry, mrz}, rotation_axis), rotation_precision))) or (antiScType == "anti-fw" and not isBackwards(v)) or (antiScType == "anti-bw" and isBackwards(v)) then
							-- no, we don't want to do insta-kill payloads, that shit is nasty in editor
							-- also 'loadstring' got restricted by MTA XDDD
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
		
			removeEventHandler("onClientMarkerHit", previewMarker.marker, previewMarker.func)

			local funq = function(e, d) 
				if e == localPlayer and d then
					local v = getPedOccupiedVehicle(e)
					if v and getVehicleController(v) == e then
						local rx, ry, rz = getElementRotation(v)
						local mrx, mry, mrz = unpack(selector.r)
						if (antiScType == "rotation" and not (is_within_tolerance(direction_vector({rx, ry, rz}, rotation_axis), direction_vector({mrx, mry, mrz}, rotation_axis), rotation_precision))) or (antiScType == "anti-fw" and not isBackwards(v)) or (antiScType == "anti-bw" and isBackwards(v)) then
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
	
	local firstTimeIsBackwards = ((firstTime == true and (scriptType == "anti-fw" or scriptType == "anti-bw")) and function() local file = fileOpen("isbackwards.lua") local data = fileRead(file, fileGetSize(file)) fileClose(file) return "\n\n\n\n\n\n"..data end) or ""
	local firstTimeIsBackwardsCode = (type(firstTimeIsBackwards) == "function" and firstTimeIsBackwards()) or ""
	
	local firstTimeRotationAntiSc = (firstTime == true and scriptType == "rotation" and function() local file = fileOpen("rotation-antisc.lua") local data = fileRead(file, fileGetSize(file)) fileClose(file) return "\n\n\n\n\n\n"..data end) or ""
	local firstTimeRotationCode = (type(firstTimeRotationAntiSc) == "function" and firstTimeRotationAntiSc()) or ""
	
	local firstTimeIntroComment = (firstTime == true and "-- //\n-- // MARKERS ANTI-SC\n-- //\n\n") or ""
	local firstTimePasteComment = (firstTime == true and "\n\n-- now place new markers under this spot") or ""

	local payloadCondition = (scriptType == "rotation" and "not (is_within_tolerance(direction_vector({getElementRotation(v)}, '"..rotation_axis.."'), direction_vector({"..tostring(float(selector.r[1]))..", "..tostring(float(selector.r[2]))..", "..tostring(float(selector.r[3])).."}, '"..rotation_axis.."'), ".. tostring(rotation_precision).."))") or (scriptType == "anti-fw" and "not (isBackwards(v))") or (scriptType == "anti-bw" and "(isBackwards(v))") or "true" -- rollback, trigger everytime the marker is touched (why? idk u tell me)
	
	local markerPosition = tostring(float(selector.p[1]))..", "..tostring(float(selector.p[2]))..", "..tostring(float(selector.p[3]))
	local markerVariable = 'createMarker('..markerPosition..', "corona", '..tostring(markerSize)..', '..tostring(markerR)..', '..tostring(markerG)..', '..tostring(markerB)..', '..tostring(markerAlpha)..')'
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
end)]] .. firstTimePasteComment .. firstTimeIsBackwardsCode .. firstTimeRotationCode

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
		if not previewMarker then return end
		if state then
			setElementDimension(previewMarker.marker, 1384)
		else
			setTimer(function()
				if isTesting then return end
				if previewMarker then
					if (getKeyState("mouse1") or getKeyState("mouse2")) then return end
					setElementDimension(previewMarker.marker, getElementDimension(localPlayer)) -- you could be in testing or map editing
				end
			end, 50, 1)
		end
	end
end
addEventHandler("onClientKey", root, clickEvents)

function onRender()

	if not showGuides then return end
	
	if eventName == "onClientPreRender" then -- this renders vehicle line correctly
		local v = getPedOccupiedVehicle(localPlayer)
		if v and antiScType == "rotation" then --for k,v in ipairs(getElementsByType("vehicle", root, true)) do
			local x, y, z = getElementPosition(v)
			local rx, ry, rz = getElementRotation(v)
			local dx, dy, dz = unpack(direction_vector({rx, ry, rz}, rotation_axis))
			dxDrawLine3D(x, y, z, x+dx*10, y+dy*10, z+dz*10, 0xFFAAAAAA, 5)
		end
	end
	
	if eventName == "onClientRender" then -- this renders markers text and line correctly
		if previewMarker then
			local x, y, z = getElementPosition(previewMarker.marker)
			
			if antiScType == "rotation" then
				local rx, ry, rz = unpack(selector.r)
				local dx, dy, dz = unpack(direction_vector({rx, ry, rz}, rotation_axis))
				dxDrawLine3D(x, y, z, x+dx*10, y+dy*10, z+dz*10, 0xFFFFAAAA, 5)
			end
			
			local pX, pY, pZ = getCameraMatrix()
			
			if getDistanceBetweenPoints3D(pX, pY, pZ, x, y, z) < 300 then
				local sX, sY = getScreenFromWorldPosition(x, y, z + 1, 0.1)
				if sX and sY then
					local text = (antiScType == "rotation" and "ROT") or (antiScType == "anti-fw" and "BW") or "FW"
					dxDrawText(text, sX+1, sY+1, sX+1, sY+1, 0xFF000000, 1.2, "arial", "center", "center")
					dxDrawText(text, sX, sY, sX, sY, 0xFFFFAAAA, 1.2, "arial", "center", "center")
				end
			end
			
		end
	end
end
addEventHandler("onClientRender", root, onRender)
addEventHandler("onClientPreRender", root, onRender)
	
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
