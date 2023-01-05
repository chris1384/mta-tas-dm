-- * TAS - Recording Tool by chris1384 @2020

-- Global values
local screenW, screenH = guiGetScreenSize()
local global = 	{
						-- global toggle
						recording = false, -- do not change
						playbacking = false, -- do not change
						recording_fbf = false, -- do not change
						rewinding = false, -- do not change
						
						fbf_switch = 0, -- important and explanation:
						-- 0: fbf is running, frame freezed
						-- 1: awaiting next frame for position update
						-- 2: return to 0 and freeze the frame again
						
						step = 0, -- important
						step_cached = 0, -- lazy variable, used for slow rewinding
						slow_pressed = false, -- lazy variable, used for slow rewinding
						
						
						-- settings
						settings = 	{
										trigger_mapStart = false, -- start recording on map start. if there's data found, switch to automatic playback instead (merged into one variable)
										stopPlaybackFinish = false, -- prevent freezing the position on last frame of playbacking
										showDebug = false, -- show debugging info (also works on script start)
										seeThroughBuilds = false, -- render pathway through objects (unused)
										sensitiveRecording = false, -- trigger adding a frame right after the recording state has changed (keep it disabled as it's outdated and might produce extra frames)
										
										warnUser = true, -- warn the user before starting a new recording or before overwritting a saved file
										
										showPath = true, -- show debug pathways
										frameSkipping = 15, -- used for rendering pathways, change to a greater value for lower detail of the run
										displayedFrames = 	{
																forward = 120, -- how many frames should we render ahead?
																backward = 0 -- and behind
															},
									},
						
						-- settings for drawn info
						dx_settings = 	{
											offsetH = 100,
										},
						
						recorded_fps = getFPSLimit(),
						fps = 0,
						timers = 	{
										fbf = nil, -- used for holding the previous frame button (unused)
										record = nil, -- warn for new record
										save = nil, -- warn for overwriting
										clear = nil -- warn for clearing all data
									},
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
								autotas = "autotas", -- new
								clear_all = "clearall", -- new
								help = "tashelp",
							}
							
-- Recording data
local global_data = {}
local global_warps = {}
local entities = {}

-- Registered keys
local registered_keys = {
							["w"] = "accelerate", 
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
local math_floor = math.floor
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber
local tocolor = tocolor

local getKeyState = getKeyState
local getPedOccupiedVehicle = getPedOccupiedVehicle
local getPedControlState = getPedControlState
local getVehicleController = getVehicleController
local getVehicleNitroLevel = getVehicleNitroLevel
local getVehicleUpgradeOnSlot = getVehicleUpgradeOnSlot
local isVehicleWheelOnGround = isVehicleWheelOnGround
local isVehicleNitroActivated = isVehicleNitroActivated
local isVehicleNitroRecharging = isVehicleNitroRecharging
local getCameraTarget = getCameraTarget
local getElementPosition = getElementPosition
local getElementRotation = getElementRotation
local getElementVelocity = getElementVelocity
local getElementAngularVelocity = getElementAngularVelocity
local getElementModel = getElementModel
local getElementHealth = getElementHealth
local getElementType = getElementType

local setPedControlState = setPedControlState
local setElementPosition = setElementPosition
local setElementRotation = setElementRotation
local setElementVelocity = setElementVelocity
local setElementAngularVelocity = setElementAngularVelocity
local setElementModel = setElementModel
local setElementHealth = setElementHealth
local setVehicleNitroLevel = setVehicleNitroLevel
local setVehicleNitroActivated = setVehicleNitroActivated

local dxDrawLine3D = dxDrawLine3D
local dxDrawRectangle = dxDrawRectangle
local dxDrawText = dxDrawText

-- Initializing
addEventHandler("onClientResourceStart", resourceRoot, function()

	outputChatBox("[TAS] #FFFFFFRecording Tool by #FFAAFFchris1384 #FFFFFFhas started!", 255, 100, 100, true)
	outputChatBox("[TAS] #FFFFFFType #FF6464/"..registered_commands.help.." #FFFFFFfor commands!", 255, 100, 100, true)
	
	for _,v in pairs(registered_commands) do
		addCommandHandler(v, globalCommands)
	end
	
	addEventHandler("onClientPreRender", root, function(deltaTime) global.fps = 1000/deltaTime end) -- remade as an entire function
	
	bindKey("backspace", "both", globalKeys) -- rewinding
	
	if global.settings.showDebug then
		addEventHandler("onClientHUDRender", root, renderDebug)
		addEventHandler("onClientHUDRender", root, renderPathway)
	end
	
end)

-- Registering custom events
addEvent("tas:triggerCommand", true)
addEventHandler("tas:triggerCommand", root, function(command)
	if not global.settings.trigger_mapStart then return end
	if command == "Started" then
		if global.recording or global.recording_fbf or global.playback then return end
		if #global_data > 0 then
			executeCommandHandler("playback")
		else
			executeCommandHandler("record")
		end
	elseif command == "Stop" then
		if global.recording then
			executeCommandHandler("record")
		elseif global.recording_fbf then
			executeCommandHandler("recordf")
		elseif global.playbacking then
			executeCommandHandler("playback")
		end
	end
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
			if #global_data > 0 and global.settings.warnUser and not (global.timers.record and isTimer(global.timers.record)) then
				global.timers.record = setTimer(function() global.timers.record = nil end, 5000, 1)
				outputChatBox("[TAS] #FFFFFFAre you sure you want to start a new recording? Type #FF6464/"..registered_commands.record.." #FFFFFFto continue.", 255, 100, 100, true)
				return
			end
			global.recording = true
			if global.timers.record then if isTimer(global.timers.record) then killTimer(global.timers.record) end global.timers.record = nil end
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
			if #global_data > 0 and global.settings.warnUser and not (global.timers.record and isTimer(global.timers.record)) then
				global.timers.record = setTimer(function() global.timers.record = nil end, 5000, 1)
				outputChatBox("[TAS] #FFFFFFAre you sure you want to start a new recording? Type #FF6464/"..registered_commands.record_frame.." #FFFFFFto continue.", 255, 100, 100, true)
				return
			end
			if global.recording then
				global.recording = false
				removeEventHandler("onClientRender", root, renderRecording)
				outputChatBox("[TAS] #FFFFFFRegular recording enabled, switching to frame-by-frame!", 255, 100, 100, true)
			end
			global.recording_fbf = true
			if global.timers.record then if isTimer(global.timers.record) then killTimer(global.timers.record) end global.timers.record = nil end
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
		
		
	-- record switch
	elseif cmd == registered_commands.switch_record then
		if global.playbacking then
			outputChatBox("[TAS] #FFFFFFSwitching failed, stop playbacking first!", 255, 100, 100, true)
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
	-- save
	elseif cmd == registered_commands.save_warp then
		if vehicle then
			if isPedDead(localPlayer) or getVehicleController(vehicle) ~= localPlayer then return end

			local x, y, z = getElementPosition(vehicle)
			local rx, ry, rz = getElementRotation(vehicle)
			local vx, vy, vz = getElementVelocity(vehicle)
			local rvx, rvy, rvz = getElementAngularVelocity(vehicle)
			local model = getElementModel(vehicle)
			local health = getElementHealth(vehicle)
			local nitro = nil
			if getVehicleUpgradeOnSlot(vehicle, 8) then
				nitro = getVehicleNitroLevel(vehicle)
			end
			table_insert(global_warps, 	{
								p = {_float(x), _float(y), _float(z)},
								r = {_float(rx), _float(ry), _float(rz)},
								v = {_float(vx), _float(vy), _float(vz)},
								rv = {_float(rvx), _float(rvy), _float(rvz)},
								m = model,
								h = _float(health),
								n = _float(nitro),
								s = #global_data
							}
						)
			outputChatBox("[TAS] #FFFFFFWarp #3cb4ff#"..tostring(#global_warps).." #ffffffsaved!", 60, 180, 255, true)
		end
	-- load (yes, you can actually use this as a save/load warp script without the use of recording)
	elseif cmd == registered_commands.load_warp then
		-- aight hear me out, this part was actually really messed up before, now it should work flawlessly, otherwise, burn your pc to ashes
		if vehicle then
			if isPedDead(localPlayer) or getVehicleController(vehicle) ~= localPlayer then return end
			if #global_warps == 0 then outputChatBox("[TAS] #FFFFFFLoading warp failed, no data found!", 255, 100, 100, true) return end
			if global.playbacking then outputChatBox("[TAS] #FFFFFFLoading warp failed, please disable playbacking!", 255, 100, 100, true) return end
			if global.recording_fbf then outputChatBox("[TAS] #FFFFFFLoading warp failed, please switch to REGULAR recording!", 255, 100, 100, true) return end -- still to be worked on
			local w_data = global_warps[#global_warps]
			if global.recording then
				removeEventHandler("onClientRender", root, renderRecording)
				global.step = w_data.s
				local recorded_cache = {}
				for i=1, global.step do
					table_insert(recorded_cache, global_data[i])
				end
				global_data = recorded_cache
			end
			setElementModel(vehicle, w_data.m)
			setElementHealth(vehicle, w_data.h)
			setElementPosition(vehicle, w_data.p[1], w_data.p[2], w_data.p[3])
			setElementRotation(vehicle, w_data.r[1], w_data.r[2], w_data.r[3])
			setElementFrozen(vehicle, true)
			if global.warp_timer then if isTimer(global.warp_timer) then killTimer(global.warp_timer) end global.warp_timer = nil end
			-- i hate this part so much
			global.warp_timer = setTimer(function()
				setElementFrozen(vehicle, false)
				setElementVelocity(vehicle, w_data.v[1], w_data.v[2], w_data.v[3])
				setElementPosition(vehicle, w_data.p[1], w_data.p[2], w_data.p[3])
				if getVehicleUpgradeOnSlot(vehicle, 8) then
					if w_data.n then
						setVehicleNitroLevel(vehicle, w_data.n)
					end
				end
				if global.recording then
					if global.settings.sensitiveRecording then renderRecording() end
					addEventHandler("onClientRender", root, renderRecording)
				end
				setElementRotation(vehicle, w_data.r[1], w_data.r[2], w_data.r[3])
				setElementAngularVelocity(vehicle, w_data.rv[1], w_data.rv[2], w_data.rv[3])
			end, 500, 1)
			outputChatBox("[TAS] #FFFFFFWarp #ffb43c#"..tostring(#global_warps).." #ffffffloaded!", 255, 180, 60, true)
		end
	-- delete
	elseif cmd == registered_commands.delete_warp then
		if #global_warps == 1 then outputChatBox("[TAS] #FFFFFFWarp #1 cannot be deleted!", 255, 100, 100, true) return end
		table_remove(global_warps, #global_warps)
		outputChatBox("[TAS] #FFFFFFWarp #ff3232#"..tostring(#global_warps).." #ffffffdeleted!", 255, 50, 50, true)
		
		
	-- resuming
	elseif cmd == registered_commands.resume then
		-- aight so this part is a sign of dodgy code (love tom), it's hella ugly
		local frame = #global_data-1 -- added -1 because it triggered a funny error message before
		if args[1] and tonumber(args[1]) then -- wow tryna make fun of myself that's ugly
			frame = tonumber(args[1])
		end
		if frame > #global_data or frame < 1 then outputChatBox("[TAS] #FFFFFFResuming run failed, you can't resume from that frame!", 255, 100, 100, true) return end
		if vehicle then
			if isPedDead(localPlayer) or getVehicleController(vehicle) ~= localPlayer then return end
			if #global_data == 0 then outputChatBox("[TAS] #FFFFFFResuming run failed, no data found!", 255, 100, 100, true) return end
			if global.playback then outputChatBox("[TAS] #FFFFFFResuming run failed, please stop playbacking!", 255, 100, 100, true) return end
			if global.recording or global.recording_fbf then outputChatBox("[TAS] #FFFFFFResuming run failed, please stop recording first!", 255, 100, 100, true) return end
			local recorded_cache = {}
			for i=1, frame do -- I WAS DOING IT ALL RIGHT BEFORE, WHY NOT DO THAT AT THE LOAD WARP PART
				table_insert(recorded_cache, global_data[i])
			end
			global_data = recorded_cache
			global.recording = true
			local w_data = global_data[#global_data]
			table_insert(global_warps, 	{
								p = {w_data.p[1], w_data.p[2], w_data.p[3]},
								r = {w_data.r[1], w_data.r[2], w_data.r[3]},
								v = {w_data.v[1], w_data.v[2], w_data.v[3]},
								rv = {w_data.rv[1], w_data.rv[2], w_data.rv[3]},
								m = w_data.m,
								h = w_data.h,
								n = w_data.n.l or nil, -- untested
								s = #global_data
							}
						)
			setElementModel(vehicle, w_data.m)
			setElementHealth(vehicle, w_data.h)
			setElementPosition(vehicle, w_data.p[1], w_data.p[2], w_data.p[3])
			setElementRotation(vehicle, w_data.r[1], w_data.r[2], w_data.r[3])
			setElementFrozen(vehicle, true)
			if global.warp_timer then if isTimer(global.warp_timer) then killTimer(global.warp_timer) end global.warp_timer = nil end
			-- i hate this part so much
			global.warp_timer = setTimer(function()
				setElementFrozen(vehicle, false)
				setElementPosition(vehicle, w_data.p[1], w_data.p[2], w_data.p[3])
				setElementRotation(vehicle, w_data.r[1], w_data.r[2], w_data.r[3])
				setElementVelocity(vehicle, w_data.v[1], w_data.v[2], w_data.v[3])
				setElementAngularVelocity(vehicle, w_data.rv[1], w_data.rv[2], w_data.rv[3])
				if getVehicleUpgradeOnSlot(vehicle, 8) then
					if w_data.n and w_data.n.l then
						setVehicleNitroLevel(vehicle, w_data.n.l)
					end
				end
				if global.recording then
					if global.settings.sensitiveRecording then renderRecording() end
					addEventHandler("onClientRender", root, renderRecording)
				end
			end, 500, 1)
			outputChatBox("[TAS] #FFFFFFRun resumed from frame #64ff64#"..tostring(frame).." #ffffff! Recording frames..", 100, 255, 100, true)
			outputChatBox("[TAS] #FFFFFFSaved warp as #3cb4ff#"..tostring(#global_warps).." #ffffff!", 60, 180, 255, true)
		end
		
		
	-- seeking
	elseif cmd == registered_commands.seek then
		local frame
		if args[1] and tonumber(args[1]) then
			frame = tonumber(args[1])
		else
			outputChatBox("[TAS] #FFFFFFSeeking failed, frame number is required!", 255, 100, 100, true)
			return
		end
		if global.recording or global.recording_fbf then outputChatBox("[TAS] #FFFFFFSeeking failed, this can only be used while playbacking!", 255, 100, 100, true) return end
		if frame < 1 or frame > #global_data then outputChatBox("[TAS] #FFFFFFSeeking failed, frame number does not exist!", 255, 100, 100, true) return end
		if global.playbacking then
			global.step = frame
			outputChatBox("[TAS] #FFFFFFSeek to frame #6464FF#"..tostring(frame).."#ffffff!", 100, 100, 255, true)
		end
		
	-- loading and saving
	-- save run
	elseif cmd == registered_commands.save_record then
		if args[1] then
			if #global_data > 0 then
				local file_name = "saves/"..args[1]..".txt" -- got rid of that mf
				if fileExists("@"..file_name) then
					if global.settings.warnUser and not (global.timers.save and isTimer(global.timers.save)) then
						global.timers.save = setTimer(function() global.timers.save = nil end, 5000, 1)
						outputChatBox("[TAS] #FFFFFFAre you sure you want to overwrite #FF6464'"..file_name.."'#ffffff? Type #FF6464/"..registered_commands.save_record.." [file] #FFFFFFto continue.", 255, 100, 100, true)
						return
					else
						if global.timers.save then if isTimer(global.timers.save) then killTimer(global.timers.save) end global.timers.save = nil end
						fileDelete("@"..file_name)
					end
				end
				local file = fileCreate("@"..file_name)
				if file then
					--local whole_ass_data = {recording_data = global_data, details = {warps = {}, }} -- still to be worked on
					fileWrite(file, toJSON(global_data))
					fileClose(file)
					outputChatBox("[TAS] #FFFFFFSaved file as #FFFF64"..file_name.."#ffffff!", 255, 255, 100, true)
				end
			end
		end
	-- load record
	elseif cmd == registered_commands.load_record then
		if args[1] then
			local success = false
			local file_name = "saves/"..tostring(args[1])..".txt"
			local file = fileOpen("@"..file_name)
			if file then
				local size = fileGetSize(file)
				local file_data = fileRead(file, size)
				local convert = fromJSON(file_data)
				if convert and type(convert) == "table" then
					if convert[1].p and convert[1].r and convert[1].v and convert[1].rv then
						global_data = convert
						success = true
					end
				end
				fileClose(file)
			end
			if success then
				outputChatBox("[TAS] #FFFFFFLoaded file #FFFF64"..file_name.."#ffffff with #FFFF64#"..tostring(#global_data).."#ffffff frames, ready for use!", 255, 255, 100, true)
			else
				outputChatBox("[TAS] #FFFFFFLoading file failed, it does not exist or it has invalid data!", 255, 100, 100, true)
			end
		end
		
		
	-- debug
	elseif cmd == registered_commands.debug then
		if global.settings.showDebug then
			global.settings.showDebug = false
			removeEventHandler("onClientHUDRender", root, renderDebug)
			removeEventHandler("onClientHUDRender", root, renderPathway)
			outputChatBox("[TAS] #FFFFFFDebugging is now #FF64FFDISABLED!", 255, 100, 255, true)
		else
			global.settings.showDebug = true
			addEventHandler("onClientHUDRender", root, renderDebug)
			addEventHandler("onClientHUDRender", root, renderPathway)
			outputChatBox("[TAS] #FFFFFFDebugging is now #FF64FFENABLED!", 255, 100, 255, true)
		end
	
	-- autotas
	elseif cmd == registered_commands.autotas then
		if global.settings.trigger_mapStart then
			global.settings.trigger_mapStart = false
			outputChatBox("[TAS] #FFFFFFAuto-TAS is now #FF64FFDISABLED!", 255, 100, 255, true)
		else
			global.settings.trigger_mapStart = true
			outputChatBox("[TAS] #FFFFFFAuto-TAS is now #FF64FFENABLED!", 255, 100, 255, true)
		end
		
	-- clear all
	elseif cmd == registered_commands.clear_all then
		if global.recording or global.recording_fbf or global.playbacking then outputChatBox("[TAS] #FFFFFFClearing failed, stop recording or playbacking first!", 255, 100, 100, true) return end
		if global.settings.warnUser and not (global.settings.clear and isTimer(global.settings.clear)) then
			global.settings.clear = setTimer(function() global.settings.clear = nil end, 5000, 1)
			outputChatBox("[TAS] #FFFFFFAre you sure you want to clear all data? Type #FF6464/"..registered_commands.clear_all.." #FFFFFFto continue.", 255, 100, 100, true)
			return
		end
		global.settings.clear = nil
		global_data = {}
		global_warps = {}
		outputChatBox("[TAS] #FFFFFFRecorded data and warps have been cleared!", 255, 100, 255, true)
		
	-- tashelp
	elseif cmd == registered_commands.help then
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.record.." | /"..registered_commands.record_frame.." - start recording | frame-by-frame recording", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.playback.." - start playbacking the recorded data", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.switch_record.." - switch between frame-by-frame and regular recording", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.next_frame.." [frames] | /"..registered_commands.previous_frame.." [frames] - next | previous frame recording", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.resume.." [frame] - continue recording (from frame number)", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.seek.." [frame] - seek to a frame number during playbacking", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.save_warp.." | /"..registered_commands.load_warp.." | /"..registered_commands.delete_warp.." - save | load | delete warp", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFFBACKSPACE - rewind during recording (+L-SHIFT fast rewind | +L-ALT slow rewind)", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.load_record.." [file] | /"..registered_commands.save_record.." [file] - load | save record data", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.autotas.." | /"..registered_commands.clear_all.." - toggle AUTO-TAS | clear all data (including warps)", 255, 100, 100, true)
		outputChatBox("[TAS] #FFFFFF/"..registered_commands.debug.." - toggle debugging", 255, 100, 100, true)
	end
	
end

function globalKeys(key, state)
	if key == "backspace" then
		if global.recording then -- when recording
			if state == "down" then
				global.rewinding = true
				global.step = #global_data
				global.step_cached = global.step
				removeEventHandler("onClientRender", root, renderRecording)
				addEventHandler("onClientRender", root, renderPlaybacking)
				--outputChatBox("[TAS] #FFFFFFRewinding..", 100, 255, 255, true)
			else
				global.rewinding = false
				removeEventHandler("onClientRender", root, renderPlaybacking)
				addEventHandler("onClientRender", root, renderRecording)
				resetBinds()
				global.slow_pressed = false
				--outputChatBox("[TAS] #FFFFFFRewinding complete!", 100, 255, 255, true)
			end

		-- to be continued
		elseif global.recording_fbf then -- when fbf recording
			return
		elseif global.playbacking then -- when playbacking
			return
		else -- when lifeless
			return
		end
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
			local nitro = nil -- changed this one to nil, just to save some space
			if getVehicleUpgradeOnSlot(vehicle, 8) then
				nitro = {l = _float(getVehicleNitroLevel(vehicle)), r = isVehicleNitroRecharging(vehicle), a = isVehicleNitroActivated(vehicle)}
			end
			local keys = {}
			
			for k,v in pairs(registered_keys) do
				if getKeyState(k) then
					table_insert(keys, k)
				end
			end
			
			local vehicle_onground = nil -- changed to nil because it might be wasteful to store unnecessary data
			
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
	if vehicle and getVehicleController(vehicle) == localPlayer then
		if global.fbf_switch == 1 then
			removeEventHandler("onClientRender", root, renderPlaybacking)
			-- this is an anomaly, the event below MIGHT trigger after the next~NEEEXT frame was rendered
			-- i'm making sure it is working as it should
			if global.settings.sensitiveRecording then renderRecording() end
			addEventHandler("onClientRender", root, renderRecording)
			return
		end
		
		local data = global_data[global.step]
		
		setElementPosition(vehicle, unpack(data.p))
		setElementRotation(vehicle, unpack(data.r))
		setElementVelocity(vehicle, unpack(data.v))
		setElementAngularVelocity(vehicle, unpack(data.rv))
		if getElementModel(vehicle) ~= data.m then setElementModel(vehicle, data.m) end -- is it really doing it better or something?
		setElementHealth(vehicle, data.h)
		
		if getVehicleUpgradeOnSlot(vehicle, 8) then
			-- this is the part that was left unfixed for a while, it should work fine now cool cool
			if data.n then -- what, am i dumb? "duud told us it was fixed, shame on him!". the thing is everything was tested on freeroam so there's this reason.. so you can blame me
				if not data.n.a and data.n.r then
					setVehicleNitroActivated(vehicle, false)
				elseif data.n.a and not data.n.r then
					if not isVehicleNitroActivated(vehicle) then 
						setVehicleNitroActivated(vehicle, true) 
					end
				end
				if data.n.l then setVehicleNitroLevel(vehicle, data.n.l) end
			end
		end
		
		-- tbh? this could be improved a lot but idk
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
		
		-- it's important
		if global.recording_fbf and global.fbf_switch == 0 then 
			return 
		elseif global.rewinding then -- becomes tricky, since i did announce slow and fast rewinding (and it becomes very ugly indeed)
		
			-- 1st part, FAST REWINDING
			if getKeyState("lshift") then
				if #global_data > 2 then
					global.step = global.step - 2
					for i=1, 2 do table_remove(global_data, #global_data) end
				else
					global.step = 1
				end
				
			-- OWW WHAT DA HEEEEEEEEEEEEEEEEEEEEEEEEEE
			-- 2ND part, ~sloooooow~ REWINDING
			elseif getKeyState("lalt") then
				if not global.slow_pressed then
					global.step_cached = #global_data
					global.slow_pressed = true
				end
				global.step_cached = global.step_cached - 0.25
				if #global_data <= 2 then
					global.step_cached = 2
					global.step = 2
				elseif global_data[global.step_cached] then
					if #global_data > 2 then
						global.step = global.step_cached
						table_remove(global_data, #global_data)
					end
				end
				
			-- if there's no extra key press
			-- 3rd part, regular rewinding
			else
				if #global_data > 2 then
					global.step = global.step - 1 
					table_remove(global_data, #global_data)
				else
					global.step = 2
				end
				if global.slow_pressed then global.slow_pressed = false end
			end
			return 
		end
		global.step = global.step + 1
		if global.step > #global_data then 
			if global.settings.stopPlaybackFinish then 
				global.playbacking = false
				removeEventHandler("onClientRender", root, renderPlaybacking)
				resetBinds()
				outputChatBox("[TAS] #FFFFFFPlaybacking ended!", 100, 100, 255, true)
			end
			global.step = #global_data
		end
		
	else
		if global.playbacking then
			global.playbacking = false
			removeEventHandler("onClientRender", root, renderPlaybacking)
			resetBinds()
			outputChatBox("[TAS] #FFFFFFStopped playbacking due to an error!", 255, 100, 100, true)
		end
	end
end

function resetBinds()
	for k,v in pairs(registered_keys) do
		setPedControlState(localPlayer, v, false)
	end
end

function renderDebug()

	local rc_stat = "#FF6464FALSE"
	if global.recording then rc_stat = "#64FF64TRUE" elseif global.recording_fbf then rc_stat = "#64FF64TRUE (Frame-By-Frame)" elseif global.timers.record then rc_stat = "#FFFF64AWAITING STATUS.." end
	if global.rewinding then rc_stat = "#64FF64TRUE #64FFFF(REWINDING..)" end
	
	local fps_stat = ""
	if global.fps < global.recorded_fps - 2 then
		fps_stat = "#FF6464-- FPS-DISCREPANCY ("..tostring(math_floor(global.fps)).." < "..tostring(global.recorded_fps)..")" 
	elseif global.fps > global.recorded_fps + 2 then
		fps_stat = "#FF6464-- FPS-DISCREPANCY ("..tostring(math_floor(global.fps)).." > "..tostring(global.recorded_fps)..")" 
	end
	
	local pb_stat = "#FF6464FALSE"
	if global.playbacking then 
		pb_stat = "#64FF64TRUE" 
	end
	
	_text("Recording: "..rc_stat.." "..fps_stat, screenW/2-global.dx_settings.offsetH+170, screenH-200, 0, 0, 1, "default", "left", "top", false, false, false, true)
	_text("Playbacking: "..pb_stat, screenW/2-global.dx_settings.offsetH+170, screenH-200+18, 0, 0, 1, "default", "left", "top", false, false, false, true)
	_text("Current Frame: #"..tostring(global.step).." | Cached: #"..tostring(global.step_cached).."", screenW/2-global.dx_settings.offsetH+170, screenH-200+18*2, 0, 0, 1, "default", "left", "top", false, false, false, true)
	_text("Total Frames: #"..tostring(#global_data).."", screenW/2-global.dx_settings.offsetH+170, screenH-200+18*3, 0, 0, 1, "default", "left", "top", false, false, false, true)
	_text("Warp ID: #00FFFF#"..tostring(#global_warps).."", screenW/2-global.dx_settings.offsetH+170, screenH-200+18*4, 0, 0, 1, "default", "left", "top", false, false, false, true)
	
	drawKey("W", screenW/2-global.dx_settings.offsetH, screenH-200, 40, 40, getPedControlState(localPlayer, "accelerate") and tocolor(60, 255, 60, 255))
	drawKey("S", screenW/2-global.dx_settings.offsetH, screenH-200+44, 40, 40, getPedControlState(localPlayer, "brake_reverse") and tocolor(255, 60, 60, 255))
	drawKey("A", screenW/2-global.dx_settings.offsetH-44, screenH-200+44, 40, 40, getPedControlState(localPlayer, "vehicle_left") and tocolor(255, 180, 60, 255))
	drawKey("D", screenW/2-global.dx_settings.offsetH+44, screenH-200+44, 40, 40, getPedControlState(localPlayer, "vehicle_right") and tocolor(255, 180, 60, 255))
	drawKey("FIRE", screenW/2-global.dx_settings.offsetH-64, screenH-200+88, 60, 40, (getPedControlState(localPlayer, "vehicle_fire") or getPedControlState(localPlayer, "vehicle_secondary_fire")) and tocolor(60, 200, 255, 255))
	drawKey("SPACE", screenW/2-global.dx_settings.offsetH, screenH-200+88, 160, 40, getPedControlState(localPlayer, "handbrake") and tocolor(255, 60, 60, 255))
	drawKey("ᐱ", screenW/2-global.dx_settings.offsetH+120, screenH-200, 40, 40, getPedControlState(localPlayer, "steer_forward") and tocolor(255, 80, 255, 255))
	drawKey("ᐯ", screenW/2-global.dx_settings.offsetH+120, screenH-200+44, 40, 40, getPedControlState(localPlayer, "steer_back") and tocolor(255, 80, 255, 255))
	
end

function renderPathway()

	local displayedFrames = {1, #global_data-1}
	local frameSkipping = global.settings.frameSkipping
	
	if global.playbacking then
		displayedFrames = {global.step-global.settings.displayedFrames.backward, global.step+global.settings.displayedFrames.forward} -- if you're playbacking, preview all frames instead of skipping some of them
		frameSkipping = 1 
	end
	
	-- oh this is the part where the lines are drawn, to make it more performance friendly, just skip some frames if you're not playbacking
	if global.settings.showPath then -- why even try
		for i=displayedFrames[1],displayedFrames[2]-frameSkipping-1,frameSkipping do -- wtf is this mess?
			if global_data[i] and global_data[i+frameSkipping] then -- yeah just do that
				dxDrawLine3D(global_data[i].p[1], global_data[i].p[2], global_data[i].p[3], global_data[i+frameSkipping].p[1], global_data[i+frameSkipping].p[2], global_data[i+frameSkipping].p[3], ((global_data[i].g and global_data[i].g == 1) and tocolor(150,150,150,150)) or tocolor(255,0,0,150), 3)
			end
		end
	end
	
end

function drawKey(keyName, x, y, x2, y2, color) -- draw keys
	dxDrawRectangle(x, y, x2, y2, color or tocolor(200, 200, 200, 200))
	dxDrawText(keyName, x, y, x+x2, y+y2, tocolor(0, 0, 0, 255), 1.384, "default-bold", "center", "center")
end

function _text(text, x, y, x2, y2, ...) -- draw shadow text
	dxDrawText(text:gsub("#%x%x%x%x%x%x", ""), x+1, y+1, x2+1, y2+1, tocolor(0,0,0,255), ...)
	dxDrawText(text, x, y, x2, y2, tocolor(255,255,255,255), ...)
end

function _float(number)
	if number and type(number) == "number" then
		if number % 1 == 0 then 
			return number 
		end
		return (math_floor(number*1000))/1000 -- add another 0 for precision and then revert it cause it didn't matter
	end
end
