-- * TAS - Recording Tool by chris1384 @2020

-- Global values
local screenW, screenH = guiGetScreenSize()
local global = 	{
						-- global toggle
						recording = false, -- do not change
						playbacking = false, -- do not change
						recording_fbf = false, -- do not change
						
						fbf_switch = 0, -- important
						
						step = 0, -- important
						
						
						-- settings
						settings = 	{
										record_mapStart = false, -- trigger recording on map start (not working if recorded data is found) (unused)
										playback_mapStart = false, -- trigger playbacking on map start (unused)
										stopPlaybackFinish = false, -- prevent freezing the position on last frame of playbacking (unused)
										showDebug = false, -- show debugging info
										seeThroughBuilds = false, -- render waypoints through objects (unused)
										warnUser = true, -- warn the user before starting a new recording
									},
						
						-- settings for drawn info
						dx_settings = {}, -- unused
						
						recorded_fps = getFPSLimit(),
						fps = 0,
						userWarn_timer = nil,
					}
					
-- Registered commands (edit to your liking)
local registered_commands = {	
								record = "record",
								record_frame = "recordf",
								playback = "playback",
								save_warp = "rsw", -- had to change it because of conflicting resources
								load_warp = "rlw", -- same for this
								delete_warp = "rdw", -- and this
								switch_record = "switchr",
								next_frame = "nf",
								previous_frame = "pf",
								load_record = "loadr",
								save_record = "saver",
								resume = "resume",
								seek = "seek",
								debug = "debugr",
								help = "tashelp",
							}
							
-- Recording data
local global_data = {}
local global_warps = {}
local entities = {}

-- Registered keys
local registered_keys = {	["w"] = "accelerate", 
							["a"] = "vehicle_left",
							["s"] = "brake_reverse",
							["d"] = "vehicle_right",
							["space"] = "handbrake",
							["arrow_u"] = "steer_forward",
							["arrow_d"] = "steer_back",
							["arrow_r"] = "vehicle_right",
							["arrow_l"] = "vehicle_left",
							["lctrl"] = "vehicle_fire",
							["lalt"] = "vehicle_secondary_fire",
							--["q"] = "", -- unused (unknown control name)
							--["e"] = "", -- unused (unknown control name)
							-- ["num_4"] = "vehicle_look_left", -- unused
							-- ["num_6"] = "vehicle_look_right" -- unused 
						}

-- Optimization
local table_insert = table.insert
local table_remove = table.remove
local pairs = pairs
local ipairs = ipairs
local math_floor = math.floor
local tostring = tostring

-- Initializing
addEventHandler("onClientResourceStart", resourceRoot, function()
	outputChatBox("[TAS] #FFFFFFRecording Tool by #FFAAFFchris1384 #FFFFFFhas started!", 255, 100, 100, true)
	outputChatBox("[TAS] #FFFFFFType #FF6464/"..registered_commands.help.." #FFFFFFfor commands!", 255, 100, 100, true)
	
	for k,v in pairs(registered_commands) do
		addCommandHandler(v, globalCommands)
	end
	
	addEventHandler("onClientPreRender", root, renderFPS)
end)

-- Registering commands
function globalCommands(cmd, ...)
	local args = {...}
	local vehicle = getPedOccupiedVehicle(localPlayer)
	-- record
	if cmd == registered_commands.record then
		if global.recording then
			global.recording = false
			removeEventHandler("onClientRender", root, renderRecording)
			outputChatBox("[TAS] #FFFFFFStopped recording ("..tostring(#global_data).." steps saved)", 100, 255, 100, true)
		elseif global.recording_fbf then
			global.recording_fbf = false
			removeEventHandler("onClientRender", root, renderPlaybacking)
			outputChatBox("[TAS] #FFFFFFStopped frame-by-frame recording ("..tostring(#global_data).." steps saved)", 100, 255, 100, true)
		else
			if global.playbacking then
				outputChatBox("[TAS] #FFFFFFRecording failed, stop playbacking first!", 255, 100, 100, true)
				return
			end
			if #global_data > 0 and not global.settings.warnUser then
				global.settings.warnUser = true
				global.userWarn_timer = setTimer(function() global.settings.warnUser = false global.userWarn_timer = nil end, 5000, 1)
				outputChatBox("[TAS] #FFFFFFAre you sure you want to start a new recording? Type #FF6464/record #FFFFFFto continue.", 255, 100, 100, true)
				return
			end
			global.recording = true
			global.settings.warnUser = false
			if global.userWarn_timer then killTimer(global.userWarn_timer) global.userWarn_timer = nil end
			global_data = {}
			global.recorded_fps = getFPSLimit()
			addEventHandler("onClientRender", root, renderRecording)
			outputChatBox("[TAS] #FFFFFFRecording frames..", 100, 255, 100, true)
		end
	-- frame-by-frame record
	elseif cmd == registered_commands.record_frame then
		if global.recording_fbf then
			global.recording_fbf = false
			removeEventHandler("onClientRender", root, renderPlaybacking)
			outputChatBox("[TAS] #FFFFFFStopped frame-by-frame recording ("..tostring(#global_data).." steps saved)", 100, 255, 100, true)
		elseif global.recording then
			global.recording = false
			removeEventHandler("onClientRender", root, renderRecording)
			outputChatBox("[TAS] #FFFFFFStopped recording ("..tostring(#global_data).." steps saved)", 100, 255, 100, true)
		else
			if global.playbacking then
				outputChatBox("[TAS] #FFFFFFRecording failed, stop playbacking first!", 255, 100, 100, true)
				return
			end
			if #global_data > 0 and not global.settings.warnUser then
				global.settings.warnUser = true
				global.userWarn_timer = setTimer(function() global.settings.warnUser = false global.userWarn_timer = nil end, 5000, 1)
				outputChatBox("[TAS] #FFFFFFAre you sure you want to start a new recording? Type #FF6464/recordf #FFFFFFto continue.", 255, 100, 100, true)
				return
			end
			if global.recording then
				global.recording = false
				removeEventHandler("onClientRender", root, renderRecording)
				outputChatBox("[TAS] #FFFFFFRegular recording enabled, switching to frame-by-frame!", 255, 100, 100, true)
			end
			global.recording_fbf = true
			global.settings.warnUser = false
			if global.userWarn_timer then killTimer(global.userWarn_timer) global.userWarn_timer = nil end
			global_data = {}
			renderRecording()
			global.step = 1
			global.recorded_fps = getFPSLimit()
			addEventHandler("onClientRender", root, renderPlaybacking)
			outputChatBox("[TAS] #FFFFFFFrame-by-frame recording started!", 100, 255, 100, true)
			outputChatBox("[TAS] #FFFFFFFrame #1", 100, 255, 100, true)
		end
	-- fbf next frame
	elseif cmd == registered_commands.next_frame then
		if global.recording_fbf then
			global.fbf_switch = 1
			outputChatBox("[TAS] #FFFFFFFrame #"..tostring(#global_data+1).."", 100, 255, 100, true)
		end
	-- fbf previous frame
	elseif cmd == registered_commands.previous_frame then
		if global.recording_fbf then
			local last_step = #global_data
			global.step = last_step-1
			table_remove(global_data, last_step)
			outputChatBox("[TAS] #FFFFFFFrame #"..tostring(last_step-1).."", 100, 255, 100, true)
		end
	-- record more switch
	elseif cmd == registered_commands.switch_record then
		if global.playbacking then
			outputChatBox("[TAS] #FFFFFFRecording failed, stop playbacking first!", 255, 100, 100, true)
			return
		end
		if global.recording then
			global.recording = false
			removeEventHandler("onClientRender", root, renderRecording)
			global.recording_fbf = true
			renderRecording()
			global.step = #global_data
			addEventHandler("onClientRender", root, renderPlaybacking)
			outputChatBox("[TAS] #FFFFFFSwitched to FRAME-BY-FRAME recording!", 100, 255, 100, true)
		elseif global.recording_fbf then
			global.recording_fbf = false
			removeEventHandler("onClientRender", root, renderPlaybacking)
			global.recording = true
			addEventHandler("onClientRender", root, renderRecording)
			outputChatBox("[TAS] #FFFFFFSwitched to REGULAR recording!", 100, 255, 100, true)
		end
	-- playback
	elseif cmd == registered_commands.playback then
		if global.playbacking then
			global.playbacking = false
			removeEventHandler("onClientRender", root, renderPlaybacking)
			resetBinds()
			outputChatBox("[TAS] #FFFFFFStopped playbacking!", 100, 100, 255, true)
		else
			if global.recording or global.recording_fbf then
				outputChatBox("[TAS] #FFFFFFPlaybacking failed, stop recording first!", 255, 100, 100, true)
				return
			end
			if #global_data == 0 then
				outputChatBox("[TAS] #FFFFFFPlaybacking failed, no recorded data found!", 255, 100, 100, true)
				return
			end
			global.playbacking = true
			global.step = 1
			addEventHandler("onClientRender", root, renderPlaybacking)
			outputChatBox("[TAS] #FFFFFFPlayback started!", 100, 100, 255, true)
		end
	-- warps
	elseif cmd == registered_commands.save_warp then
		if vehicle then
			if isPedDead(localPlayer) or getCameraTargetPlayer() ~= localPlayer then return end

			local x, y, z = getElementPosition(vehicle)
			local rx, ry, rz = getElementRotation(vehicle)
			local vx, vy, vz = getElementVelocity(vehicle)
			local rvx, rvy, rvz = getElementAngularVelocity(vehicle)
			local model = getElementModel(vehicle)
			local health = getElementHealth(vehicle)
			local nitro = {}
			if getVehicleUpgradeOnSlot(vehicle, 8) then
				nitro = {l = _float(getVehicleNitroLevel(vehicle)), r = isVehicleNitroRecharging(vehicle), a = isVehicleNitroActivated(vehicle)}
			end
			table_insert(global_warps, 	{
								p = {_float(x), _float(y), _float(z)},
								r = {_float(rx), _float(ry), _float(rz)},
								v = {_float(vx), _float(vy), _float(vz)},
								rv = {_float(rvx), _float(rvy), _float(rvz)},
								m = model,
								h = _float(health),
								n = nitro.l,
								s = #global_data
							}
						)
			outputChatBox("[TAS] #FFFFFFWarp #3cb4ff#"..tostring(#global_warps).." #ffffffsaved!", 60, 180, 255, true)
		end
	elseif cmd == registered_commands.load_warp then
		if vehicle then
			if isPedDead(localPlayer) or getCameraTargetPlayer() ~= localPlayer then return end
			if #global_warps == 0 then outputChatBox("[TAS] #FFFFFFLoading warp failed, no data found!", 255, 100, 100, true) return end
			if global.recording_fbf then outputChatBox("[TAS] #FFFFFFLoading warp failed, please switch to REGULAR recording!", 255, 100, 100, true) return end -- still to be worked on
			local w_data = global_warps[#global_warps]
			if global.recording then
				removeEventHandler("onClientRender", root, renderRecording)
				global.step = w_data.s
				local recorded_cache = {}
				for i=1, global.step-1 do
					table_insert(recorded_cache, global_data[i])
				end
				global_data = recorded_cache
			end
			setElementModel(vehicle, w_data.m)
			setElementHealth(vehicle, w_data.h)
			setElementPosition(vehicle, w_data.p[1], w_data.p[2], w_data.p[3])
			setElementRotation(vehicle, w_data.r[1], w_data.r[2], w_data.r[3])
			setElementFrozen(vehicle, true)
			if global.warp_timer then killTimer(global.warp_timer) global.warp_timer = nil end
			global.warp_timer = setTimer(function()
				setElementFrozen(vehicle, false)
				setElementPosition(vehicle, w_data.p[1], w_data.p[2], w_data.p[3]) -- doing it again just to make sure
				setElementRotation(vehicle, w_data.r[1], w_data.r[2], w_data.r[3]) -- doing it again just to make sure
				setElementVelocity(vehicle, w_data.v[1], w_data.v[2], w_data.v[3])
				setElementAngularVelocity(vehicle, w_data.rv[1], w_data.rv[2], w_data.rv[3])
				setVehicleNitroLevel(vehicle, w_data.n)
				if global.recording then
					renderRecording()
					addEventHandler("onClientRender", root, renderRecording)
				end
			end, 500, 1)
			outputChatBox("[TAS] #FFFFFFWarp #ffb43c#"..tostring(#global_warps).." #ffffffloaded!", 255, 180, 60, true)
		end
	elseif cmd == registered_commands.delete_warp then
		if #global_warps == 1 then outputChatBox("[TAS] #FFFFFFWarp #1 cannot be deleted!", 255, 100, 100, true) return end
		table_remove(global_warps, #global_warps)
		outputChatBox("[TAS] #FFFFFFWarp #ff3232#"..tostring(#global_warps).." #ffffffdeleted!", 255, 50, 50, true)
	-- save run
	elseif cmd == registered_commands.save_record then
		if args[1] then
			if #global_data > 0 then
				local file_name = "saves/"..args[1].."_"..tostring(math.random(1000,9999))..".txt"
				local file = fileCreate("@"..file_name)
				if file then
					local whole_ass_data = {recording_data = global_data, details = {warps = {}, }}
					fileWrite(file, toJSON(global_data))
					fileClose(file)
					outputChatBox("[TAS] #FFFFFFSaved file as #FFFF64"..file_name.."#ffffff!", 255, 255, 100, true)
				end
			end
		end
	-- debug
	elseif cmd == registered_commands.debug then
		if global.settings.showDebug then
			global.settings.showDebug = false
			removeEventHandler("onClientHUDRender", root, renderDebug)
			outputChatBox("[TAS] #FFFFFFDebugging is now #FF64FFDISABLED!", 255, 100, 255, true)
		else
			global.settings.showDebug = true
			addEventHandler("onClientHUDRender", root, renderDebug)
			outputChatBox("[TAS] #FFFFFFDebugging is now #FF64FFENABLED!", 255, 100, 255, true)
		end
	-- tashelp
	elseif cmd == registered_commands.help then
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.record.." | /"..registered_commands.record_frame.." - start recording | frame-by-frame recording", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.playback.." - start playbacking the recorded data", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.switch_record.." - switch between frame-by-frame and regular recording", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.next_frame.." [frames] | /"..registered_commands.previous_frame.." [frames] - next | previous frame recording", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.resume.." | /"..registered_commands.seek.." [frame] - continue recording | from frame number", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.save_warp.." | /"..registered_commands.load_warp.." | /"..registered_commands.delete_warp.." - save | load | delete warp", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFFBACKSPACE - rewind during recording (+SHIFT to rewind faster)", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.load_record.." [file] | /"..registered_commands.save_record.." [file] - load | save record data", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.debug.." - toggle debugging", 255, 100, 100, true)
	end
end

function renderRecording()
	-- DISCLAIMER: onClientRender SHOULD ALWAYS BE USED INSTEAD OF onClientPreRender, this actually doesn't mess with your ped
	-- currently i'm not trying to see better alternatives, should work just fine
	local vehicle = getPedOccupiedVehicle(localPlayer)
	if vehicle then
		if getVehicleController(vehicle) == localPlayer then
		
			if global.fbf_switch == 2 then
				addEventHandler("onClientRender", root, renderPlaybacking)
				removeEventHandler("onClientRender", root, renderRecording)
				global.fbf_switch = 0
				global.step = global.step + 1
				return
			elseif global.fbf_switch == 1 then
				global.fbf_switch = 2
			end
			
			-- garbage collector
			local x, y, z = getElementPosition(vehicle)
			local rx, ry, rz = getElementRotation(vehicle)
			local vx, vy, vz = getElementVelocity(vehicle)
			local rvx, rvy, rvz = getElementAngularVelocity(vehicle)
			local model = getElementModel(vehicle)
			local health = getElementHealth(vehicle)
			local nitro = {}
			if getVehicleUpgradeOnSlot(vehicle, 8) then
				nitro = {l = _float(getVehicleNitroLevel(vehicle)), r = isVehicleNitroRecharging(vehicle), a = isVehicleNitroActivated(vehicle)}
			end
			local keys = {}
			
			for k,v in pairs(registered_keys) do
				if getKeyState(k) then
					table_insert(keys, k)
				end
			end
			
			local vehicle_onground = 0
			
			for i=0,3 do
				if isVehicleWheelOnGround(vehicle, i) then
					vehicle_onground = 1
					break
				end
			end
			
			-- brains of the operation, use the custom function to optimize it a little bit
			table_insert(global_data, 	{
											p = {_float(x), _float(y), _float(z)},
											r = {_float(rx), _float(ry), _float(rz)},
											v = {_float(vx), _float(vy), _float(vz)},
											rv = {_float(rvx), _float(rvy), _float(rvz)},
											m = model,
											h = _float(health),
											n = nitro,
											k = keys,
											g = vehicle_onground
										}
						)
			
		end
	else
		global.recording = false
		removeEventHandler("onClientRender", root, renderRecording)
		outputChatBox("[TAS] #FFFFFFStopped recording because of an error ("..tostring(#global_data).." steps saved)", 255, 100, 100, true)
	end
end

function renderPlaybacking()
	-- why would i duplicate this render function just to make an another one for fbf? just make a mess out of this one already LOL
	local vehicle = getPedOccupiedVehicle(localPlayer)
	if vehicle then
		if getVehicleController(vehicle) == localPlayer then
		
			if global.fbf_switch == 1 then
				removeEventHandler("onClientRender", root, renderPlaybacking)
				-- this is an anomaly, the event below MIGHT trigger after the next~NEEEXT frame was rendered
				-- i'm making sure it is working as it should
				renderRecording()
				addEventHandler("onClientRender", root, renderRecording)
				return
			end
			
			local s = global.step
			local data = global_data[s]
			
			setElementPosition(vehicle, unpack(data.p))
			setElementRotation(vehicle, unpack(data.r))
			setElementVelocity(vehicle, unpack(data.v))
			setElementAngularVelocity(vehicle, unpack(data.rv))
			if getElementModel(vehicle) ~= data.m then setElementModel(vehicle, data.m) end -- is it really doing it better or something?
			setElementHealth(vehicle, data.h)
			
			if not data.n.a and data.n.r then
				setVehicleNitroActivated(vehicle, false)
			elseif data.n.a and not data.n.r then
				if not isVehicleNitroActivated(vehicle) then 
					setVehicleNitroActivated(vehicle, true) 
				end
			end
			setVehicleNitroLevel(vehicle, data.n.l)
			if not global.recording_fbf then
				resetBinds()
				for k,v in pairs(registered_keys) do
					for _,h in ipairs(data.k) do
						if k == h then
							setPedControlState(localPlayer, v, true)
						end
					end
				end
			end
			if global.recording_fbf and global.fbf_switch == 0 then return end
			global.step = global.step + 1
			if global.step > #global_data then global.step = #global_data end
		end
	end
end

function resetBinds()
	for k,v in pairs(registered_keys) do
		setPedControlState(localPlayer, v, false)
	end
end

local keyboard_offset = 100

function renderDebug()
	local rc_stat = "#FF6464FALSE"
	if global.recording then rc_stat = "#64FF64TRUE" elseif global.recording_fbf then rc_stat = "#64FF64TRUE (Frame-By-Frame)" elseif global.userWarn_timer then rc_stat = "#FFFF64AWAITING STATUS.." end
	
	local fps_stat = ""
	if global.fps < global.recorded_fps - 2 then
		fps_stat = "#FF6464-- FPS-DISCREPANCY ("..tostring(math_floor(global.fps)).." < "..tostring(global.recorded_fps)..")" 
	elseif global.fps > global.recorded_fps + 2 then
		fps_stat = "#FF6464-- FPS-DISCREPANCY ("..tostring(math_floor(global.fps)).." > "..tostring(global.recorded_fps)..")" 
	end
	
	local pb_stat = "#FF6464FALSE"
	if global.playbacking then pb_stat = "#64FF64TRUE" end
	
	_text("Recording: "..rc_stat.." "..fps_stat, screenW/2-keyboard_offset+170, screenH-200, 0, 0, 1, "default", "left", "top", false, false, false, true)
	_text("Playbacking: "..pb_stat, screenW/2-keyboard_offset+170, screenH-200+18, 0, 0, 1, "default", "left", "top", false, false, false, true)
	_text("Current Frame: #"..tostring(global.step).."", screenW/2-keyboard_offset+170, screenH-200+18*2, 0, 0, 1, "default", "left", "top", false, false, false, true)
	_text("Total Frames: #"..tostring(#global_data).."", screenW/2-keyboard_offset+170, screenH-200+18*3, 0, 0, 1, "default", "left", "top", false, false, false, true)
	_text("Warp ID: #00FFFF#"..tostring(#global_warps).."", screenW/2-keyboard_offset+170, screenH-200+18*4, 0, 0, 1, "default", "left", "top", false, false, false, true)
	
	drawKey("W", screenW/2-keyboard_offset, screenH-200, 40, 40, getPedControlState(localPlayer, "accelerate") and tocolor(60, 255, 60, 255))
	drawKey("S", screenW/2-keyboard_offset, screenH-200+44, 40, 40, getPedControlState(localPlayer, "brake_reverse") and tocolor(255, 60, 60, 255))
	drawKey("A", screenW/2-keyboard_offset-44, screenH-200+44, 40, 40, getPedControlState(localPlayer, "vehicle_left") and tocolor(255, 180, 60, 255))
	drawKey("D", screenW/2-keyboard_offset+44, screenH-200+44, 40, 40, getPedControlState(localPlayer, "vehicle_right") and tocolor(255, 180, 60, 255))
	drawKey("FIRE", screenW/2-keyboard_offset-64, screenH-200+88, 60, 40, (getPedControlState(localPlayer, "vehicle_fire") or getPedControlState(localPlayer, "vehicle_secondary_fire")) and tocolor(60, 200, 255, 255))
	drawKey("SPACE", screenW/2-keyboard_offset, screenH-200+88, 160, 40, getPedControlState(localPlayer, "handbrake") and tocolor(255, 60, 60, 255))
	drawKey("ᐱ", screenW/2-keyboard_offset+120, screenH-200, 40, 40, getPedControlState(localPlayer, "steer_forward") and tocolor(255, 80, 255, 255))
	drawKey("ᐯ", screenW/2-keyboard_offset+120, screenH-200+44, 40, 40, getPedControlState(localPlayer, "steer_back") and tocolor(255, 80, 255, 255))
	
	for i=1,#global_data-1 do
		local data = global_data[i]
		if global_data[i].g == 1 then
			dxDrawLine3D(global_data[i].p[1], global_data[i].p[2], global_data[i].p[3], global_data[i+1].p[1], global_data[i+1].p[2], global_data[i+1].p[3], tocolor(150,150,150,150), 3)
		else
			dxDrawLine3D(global_data[i].p[1], global_data[i].p[2], global_data[i].p[3], global_data[i+1].p[1], global_data[i+1].p[2], global_data[i+1].p[3], tocolor(255,0,0,150), 3)
		end
	end
end

function drawKey(keyName, x, y, x2, y2, color)
	dxDrawRectangle(x, y, x2, y2, color or tocolor(200, 200, 200, 200))
	dxDrawText(keyName, x, y, x+x2, y+y2, tocolor(0, 0, 0, 255), 1.384, "default-bold", "center", "center")
end

function _text(text, x, y, x2, y2, ...)
	dxDrawText(text:gsub("#%x%x%x%x%x%x", ""), x+1, y+1, x2+1, y2+1, tocolor(0,0,0,255), ...)
	dxDrawText(text, x, y, x2, y2, tocolor(255,255,255,255), ...)
end

function renderFPS(deltaTime)
	global.fps = 1000/deltaTime
end

function _float(number)
	if number and type(number) == "number" then
		if number % 1 == 0 then 
			return number 
		end
		return (math_floor(number*1000))/1000
	end
end

function getCameraTargetPlayer()
	local element = getCameraTarget()
	if element and getElementType(element) == "vehicle" then
		element = getVehicleController(element)
	else
		return false
	end
	return element
end

function isEventHandlerAdded( sEventName, pElementAttachedTo, func )
    if type( sEventName ) == 'string' and isElement( pElementAttachedTo ) and type( func ) == 'function' then
        local aAttachedFunctions = getEventHandlers( sEventName, pElementAttachedTo )
        if type( aAttachedFunctions ) == 'table' and #aAttachedFunctions > 0 then
            for i, v in ipairs( aAttachedFunctions ) do
                if v == func then
                    return true
                end
            end
        end
    end
    return false
end

