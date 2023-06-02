--[[
		* TAS - Recording Tool by chris1384 @2020
		* version 1.4
--]]

-- // the root of your problems
local tas = {
				-- // hardcoded variables, do not edit
				var = 	{
							start_tick = 0, -- begin tick
							difference_tick = 0, -- used to calculate the time difference between warps
							tick_1 = 0, -- last frame tick
							tick_2 = 0, -- next frame tick (used for interpolation)
							play_frame = 1, -- used for table indexing
				
							recording = false,
							recording_fbf = false, -- unused
							fbf_switch = 0, -- unused
							
							rewinding = false, -- unused
							
							loading_warp = false, -- restrict stopping recording when warp is loading
							
							playbacking = false,
						},
						
				data = {},
				warps = {},
				entities = {},
				
				settings = 	{
								startPrompt = true, -- show resource initialization text on startup
								promptType = 1, -- how action messages should be rendered. 0: none, 1: chatbox (default), 2: dxText (useful if server uses wrappers)
								
								stopPlaybackFinish = true, -- prevent freezing the position on last frame of playbacking
								
								warpResume = 500, -- time until the vehicle resumes from loading a warp
								debugging = false, -- show debug info
							},
				timers = {},
			}
			
-- // Registered commands (edit to your liking)
tas.registered_commands = {	
								record = "record",
								record_frame = "recordf",
								playback = "playback",
								save_warp = "rsw",
								load_warp = "rlw",
								delete_warp = "rdw",
								switch_record = "switchr",
								next_frame = "nf",
								previous_frame = "pf",
								load_record = "loadr",
								save_record = "saver",
								resume = "resume",
								seek = "seek",
								debug = "debugr",
								autotas = "autotas",
								clear_all = "clearall",
								help = "tashelp",
							}

-- // Registered keys
tas.registered_keys = {
							w = "accelerate", 
							a = "vehicle_left",
							s = "brake_reverse",
							d = "vehicle_right",
							space = "handbrake",
							arrow_u = "steer_forward",
							arrow_d = "steer_back",
							arrow_r = "vehicle_right",
							arrow_l = "vehicle_left",
							lctrl = "vehicle_fire",
							lalt = "vehicle_secondary_fire",
						}
						
-- // Local storage
local localPlayer = getLocalPlayer()
local root = getRootElement()

local getTickCount = getTickCount

local getPedOccupiedVehicle = getPedOccupiedVehicle
local getVehicleController = getVehicleController
local getVehicleNitroCount = getVehicleNitroCount
local getVehicleNitroLevel = getVehicleNitroLevel
local getVehicleNitroActivated = getVehicleNitroActivated

local setVehicleNitroCount = setVehicleNitroCount
local setVehicleNitroLevel = setVehicleNitroLevel
local setVehicleNitroActivated = setVehicleNitroActivated

local getElementPosition = getElementPosition
local getElementRotation = getElementRotation
local getElementVelocity = getElementVelocity
local getElementAngularVelocity = getElementAngularVelocity
local getElementHealth = getElementHealth
local getElementModel = getElementModel

local setElementPosition = setElementPosition
local setElementRotation = setElementRotation
local setElementVelocity = setElementVelocity
local setElementAngularVelocity = setElementAngularVelocity
local setElementHealth = setElementHealth
local setElementModel = setElementModel

local getKeyState = getKeyState
local setPedControlState = setPedControlState

local dxDrawText = dxDrawText

-- // Cool LUA
local ipairs = ipairs
local pairs = pairs
local unpack = unpack

-- // Cool math
local math_pi = 3.1415926535898
local math_deg = math.deg
local math_rad = math.rad
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_floor = math.floor

-- // Other
local table_insert = table.insert
local table_remove = table.remove
local string_gsub = string.gsub
local string_format = string.format


-- // Initialization
function tas.init()

	if tas.settings.startPrompt then
		tas.prompt("[TAS] ##Recording Tool $$v1.4 ##by #FFAAFFchris1384 ##has started!", 255, 100, 100)
		tas.prompt("[TAS] ##Type $$/tashelp ##for commands!", 255, 100, 100)
	end
	
	for _,v in pairs(tas.registered_commands) do
		addCommandHandler(v, tas.commands)
	end
	
end
addEventHandler("onClientResourceStart", resourceRoot, tas.init)

-- // Termination
function tas.stop()
	tas.resetBinds()
end
addEventHandler("onClientResourceStop", resourceRoot, tas.stop)


-- // Event Commands
function tas.commands(cmd, ...) 

	local args = {...}
	
	local vehicle = getControlledVehicle(localPlayer)
	
	-- // Record
	if cmd == tas.registered_commands.record then
		
		if not vehicle then tas.prompt("[TAS] ##Recording failed, get a $$vehicle ##first!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("[TAS] ##Recording failed, stop $$playbacking ##first!", 255, 100, 100) return end
		
		if tas.var.recording then
		
			if tas.var.loading_warp then tas.prompt("[TAS] ##Stopping record failed, please wait a bit!", 255, 100, 100) return end
			
			removeEventHandler("onClientRender", root, tas.render_record)
			tas.var.recording = false
			tas.prompt("[TAS] ##Recording stopped! ($$"..tostring(#tas.data).." ##frames)", 100, 255, 100)
		else
			tas.data = {}
			tas.warps = {}
			tas.var.recording = true
			tas.var.start_tick = getTickCount()
			tas.var.difference_tick = 0
			addEventHandler("onClientRender", root, tas.render_record)
			tas.prompt("[TAS] ##Recording frames..", 100, 255, 100)
		end
		
	-- // Playback
	elseif cmd == tas.registered_commands.playback then
	
		if #tas.data < 1 then tas.prompt("[TAS] ##Playbacking failed, no $$recorded data ##found!", 255, 100, 100) return end
		if tas.var.recording then tas.prompt("[TAS] ##Playbacking failed, stop $$recording ##first!", 255, 100, 100) return end
		
		if tas.var.playbacking then
			removeEventHandler("onClientHUDRender", root, tas.render_playback)
			tas.var.playbacking = false
			tas.resetBinds()
			tas.prompt("[TAS] ##Playbacking stopped!", 100, 100, 255)
		else
			addEventHandler("onClientHUDRender", root, tas.render_playback)
			tas.var.playbacking = true
			tas.var.play_frame = 1
			tas.var.start_tick = getTickCount()
			tas.prompt("[TAS] ##Playbacking started!", 100, 100, 255)
		end
	
	-- // Save Warp
	elseif cmd == tas.registered_commands.save_warp then
	
		if not vehicle then tas.prompt("[TAS] ##Saving warp failed, get a $$vehicle ##first!", 255, 100, 100) return end
		
		local tick, p, r, v, rv, health, model, nos, keys = tas.record_state(vehicle)
		
		table_insert(tas.warps, {
									frame = #tas.data,
									tick = tick,
									p = p,
									r = r,
									v = v,
									rv = rv,
									h = health,
									m = model,
									n = nos,
								})
								
		tas.prompt("[TAS] ##Warp $$#"..tostring(#tas.warps).." ##saved!", 60, 180, 255)
		
	-- // Load Warp
	elseif cmd == tas.registered_commands.load_warp then
		
		if not vehicle then tas.prompt("[TAS] ##Loading warp failed, get a $$vehicle ##first!", 255, 100, 100) return end
		if #tas.warps == 0 then tas.prompt("[TAS] ##Loading warp failed, no $$warps ##recorded!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("[TAS] ##Loading warp failed, stop $$playbacking ##first!", 255, 100, 100) return end
		
		tas.var.loading_warp = true
		
		local w_data = tas.warps[#tas.warps]
		
		if tas.var.recording then
			removeEventHandler("onClientRender", root, tas.render_record)
		end
		
		for i=w_data.frame, #tas.data do
			tas.data[i] = nil
		end
		
		setElementPosition(vehicle, unpack(w_data.p))
		setElementRotation(vehicle, unpack(w_data.r))
		
		setElementFrozen(vehicle, true)
		
		if getElementModel(vehicle) ~= w_data.m then
			setElementModel(vehicle, w_data.m)
			triggerServerEvent("tas:onModelChange", vehicle, w_data.m)
		end
		
		if tas.timers.load_warp then 
			killTimer(tas.timers.load_warp) 
			tas.timers.load_warp = nil 
		end
		
		tas.timers.load_warp = 	setTimer(function()
		
									setElementFrozen(vehicle, false)
									
									setElementVelocity(vehicle, unpack(w_data.v))
									setElementAngularVelocity(vehicle, unpack(w_data.rv))
									
									setElementHealth(vehicle, w_data.h)
		
									tas.nos(vehicle, w_data.n)
									
									if tas.var.recording then
										tas.var.difference_tick = (getTickCount() - w_data.tick - tas.var.start_tick)
										addEventHandler("onClientRender", root, tas.render_record)
									end
									
									tas.timers.load_warp = nil
									tas.var.loading_warp = false
									
								end, tas.settings.warpResume, 1)
								
		tas.prompt("[TAS] ##Warp $$#"..tostring(#tas.warps).." ##loaded!", 255, 180, 60)
		
	-- // Delete Warp
	elseif cmd == tas.registered_commands.delete_warp then
	
		local last_warp = #tas.warps
		
		if isCursorShowing() then return end
		if last_warp == 0 then tas.prompt("[TAS] ##Deleting warp failed, no $$warps ##recorded!", 255, 100, 100) return end
		
		table_remove(tas.warps, last_warp)
		tas.prompt("[TAS] ##Warp $$#"..tostring(last_warp).." ##deleted!", 255, 50, 50)
		
	elseif cmd == tas.registered_commands.help then
		tas.prompt("[TAS] ##/"..tas.registered_commands.record.." $$| ##/"..tas.registered_commands.playback.." $$- ##start $$| ##playback your recording", 255, 100, 100)
		tas.prompt("[TAS] ##/"..tas.registered_commands.save_warp.." $$| ##/"..tas.registered_commands.load_warp.." $$| ##/"..tas.registered_commands.delete_warp.." - ##save $$| ##load $$| ##delete a warp", 255, 100, 100)
	end
end

-- // Recording
function tas.render_record()

	local vehicle = getControlledVehicle(localPlayer)
	
	if vehicle then
	
		local tick, p, r, v, rv, health, model, nos, keys = tas.record_state(vehicle)
		
		table_insert(tas.data, 	{
									tick = tick,
									p = p,
									r = r,
									v = v,
									rv = rv,
									h = health,
									m = model,
									n = nos,
									k = keys,
								})
					
	end
end

-- // Recording vehicle state
function tas.record_state(vehicle, ped)

	if vehicle then
	
		local current_tick = getTickCount()
		local real_time = current_tick - tas.var.difference_tick - tas.var.start_tick
	
		local p = {getElementPosition(vehicle)}
		local r = {getElementRotation(vehicle)}
		local v = {getElementVelocity(vehicle)}
		local rv = {getElementAngularVelocity(vehicle)}
		
		local health = getElementHealth(vehicle)
		local model = getElementModel(vehicle)
		
		local nos
		if getVehicleUpgradeOnSlot(vehicle, 8) ~= 0 then
			local count, level = getVehicleNitroCount(vehicle), getVehicleNitroLevel(vehicle)
			if count and level then
				nos = {c = count, l = level, a = isVehicleNitroActivated(vehicle)}
			end
		end
		
		local keys = {}
		for k in pairs(tas.registered_keys) do
			if getKeyState(k) then
				table_insert(keys, k)
			end
		end
		
		return real_time, p, r, v, rv, health, model, nos, keys
					
	end
end

-- // Playbacking
function tas.render_playback()

	local vehicle = getControlledVehicle(localPlayer)
	
	if vehicle then
	
		local current_tick = getTickCount()
		local real_time = (current_tick - tas.var.start_tick) -- /20 -- inbetweening testing
		local inbetweening = 0

		if tas.var.play_frame < #tas.data or tas.data[tas.var.play_frame] then
			while real_time > tas.data[tas.var.play_frame].tick do
				tas.var.tick_1 = tas.data[tas.var.play_frame].tick
				if tas.data[tas.var.play_frame+2] then
					tas.var.tick_2 = tas.data[tas.var.play_frame+1].tick
					tas.var.play_frame = tas.var.play_frame + 1
				else
					if tas.settings.stopPlaybackFinish then
						executeCommandHandler(tas.registered_commands.playback)
						return
					end
					break
				end
			end
		end
		
		inbetweening = math_max(0, math_min((real_time - tas.var.tick_1) / (tas.var.tick_2 - tas.var.tick_1), 1))
		
		if tas.settings.debugging then
			dxDrawText("Total Frames: "..tostring(#tas.data), 600, 100, 0, 0)
			dxDrawText("Current Tick: "..tostring(current_tick).." | Real Time Tick: "..tostring(real_time), 600, 120, 0, 0)
			dxDrawText("Current Playback Frame: "..tostring(tas.var.play_frame).." | Last Tick: "..tostring(tas.var.tick_1).." | Upcoming Tick: "..tostring(tas.var.tick_2), 600, 140, 0, 0)
			dxDrawText("Inbetween: "..tostring(inbetweening), 600, 160, 0, 0)
		end
		
		local frame_data = tas.data[tas.var.play_frame]
		local frame_data_next = tas.data[tas.var.play_frame+1]
		
		local x = tas.lerp(frame_data.p[1], frame_data_next.p[1], inbetweening)
		local y = tas.lerp(frame_data.p[2], frame_data_next.p[2], inbetweening)
		local z = tas.lerp(frame_data.p[3], frame_data_next.p[3], inbetweening)
		setElementPosition(vehicle, x, y, z)
		
		local rx = tas.lerp_angle(frame_data.r[1], frame_data_next.r[1], inbetweening)
		local ry = tas.lerp_angle(frame_data.r[2], frame_data_next.r[2], inbetweening)
		local rz = tas.lerp_angle(frame_data.r[3], frame_data_next.r[3], inbetweening)
		setElementRotation(vehicle, rx, ry, rz)
		
		setElementVelocity(vehicle, unpack(frame_data.v))
		setElementAngularVelocity(vehicle, unpack(frame_data.rv))
		
		if getElementModel(vehicle) ~= frame_data.m then
			setElementModel(vehicle, frame_data.m)
			triggerServerEvent("tas:onModelChange", vehicle, frame_data.m)
		end
		setElementHealth(vehicle, frame_data.h)
		
		tas.nos(vehicle, frame_data.n)
		
		tas.resetBinds()
		for k,v in pairs(tas.registered_keys) do
			for _,h in ipairs(frame_data.k) do
				if k == h then
					setPedControlState(localPlayer, v, true)
				end
			end
		end
		
	end
end

-- // Resetting ped controls
function tas.resetBinds()
	for _,v in pairs(tas.registered_keys) do
		setPedControlState(localPlayer, v, false)
	end
end

-- // Command messages
function tas.prompt(text, r, g, b)
	return outputChatBox(string_gsub(string_gsub(text, "%#%#", "#FFFFFF"), "%$%$", string.format("#%.2X%.2X%.2X", r, g, b)), r, g, b, true)
end

-- // Useful
function tas.lerp(a, b, t)
	return a + t * (b - a)
end

-- thanks chatgpt XD (CsaWee knows)
function tas.lerp_angle(start_angle, end_angle, progress)
    local start_angle = math_rad(start_angle)
    local end_angle = math_rad(end_angle)
    if math_abs(end_angle - start_angle) > math_pi then
        if end_angle > start_angle then
            start_angle = start_angle + 2*math_pi
        else
            end_angle = end_angle + 2*math_pi
        end
    end
    local angle = (1 - progress) * start_angle + progress * end_angle
    return math_deg(angle)
end

-- // Nitro detection and modify stats
function tas.nos(vehicle, data)
	if vehicle then
		local nos_upgrade = getVehicleUpgradeOnSlot(vehicle, 8)
		if data ~= nil then
			if nos_upgrade == 0 then
				addVehicleUpgrade(vehicle, 1010)
			end
			setVehicleNitroCount(vehicle, data.c)
			setVehicleNitroLevel(vehicle, data.l)
			setVehicleNitroActivated(vehicle, data.a)
		else
			if nos_upgrade ~= 0 then
				removeVehicleUpgrade(vehicle, nos_upgrade)
			end
		end
	end
end

-- // Shortcut
function getControlledVehicle(player)
	local vehicle = getPedOccupiedVehicle(player)
	if vehicle and getVehicleController(vehicle) == player then
		return vehicle
	end
	return false
end

--[[ -- unused
function tas.float(number)
	return math_floor( number * 1000 ) * 0.01
end
]]
