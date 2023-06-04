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
		
		playbacking = false, -- magic happening
			},
			
	data = {}, -- run data
	
	settings = 	{
		stopPlaybackFinish = true, -- prevent freezing the position on last frame while playbacking

		playbackInterpolation = true, -- interpolate the movement between frames for a smoother gameplay (can get jagged with framedrops)
	
		debugging = false, -- show debug info
	},
}
			
-- // Registered commands (edit to your liking)
tas.registered_commands = {	
	playback = "playback",
	load_record = "loadr",
	debug = "debugr",
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
	
-- // Initialization
function tas.init()
	
	for _,v in pairs(tas.registered_commands) do
		addCommandHandler(v, tas.commands)
	end
	
	addEventHandler("onClientRender", root, tas.dxDebug)
	
end

-- // Termination
function tas.stop()
	tas.resetBinds()
end
addEventHandler("onClientResourceStop", resourceRoot, tas.stop)

-- // Event Commands
function tas.commands(cmd, ...) 

	local args = {...}
	
	local vehicle = tas.cveh(localPlayer)
	
	-- // Playback
	if cmd == tas.registered_commands.playback then
	
		if #tas.data < 1 then tas.prompt("[TAS] ##Playbacking failed, no $$recorded data ##found!", 255, 100, 100) return end
		if tas.var.recording then tas.prompt("[TAS] ##Playbacking failed, stop $$recording ##first!", 255, 100, 100) return end
		
		if tas.var.playbacking then
			removeEventHandler("onClientRender", root, tas.render_playback)
			tas.var.playbacking = false
			tas.resetBinds()
			
			tas.prompt("[TAS] ##Playbacking stopped!", 100, 100, 255)
		else
			addEventHandler("onClientRender", root, tas.render_playback)
			tas.var.playbacking = true
			tas.var.play_frame = 1
			tas.var.start_tick = getTickCount()
			
			tas.prompt("[TAS] ##Playbacking started!", 100, 100, 255)
		end
	
	-- // Load Recording
	elseif cmd == tas.registered_commands.load_record then
	
		local fileTarget = args[1]..".tas"
	
		if args[1] == nil then 
			tas.prompt("[TAS] ##Loading record failed, please specify the $$name ##of your file!", 255, 100, 100) 
			tas.prompt("[TAS] ##Example: $$/"..tas.registered_commands.load_record.." od3", 255, 100, 100) 
			return 
		end
		
		local load_file = (fileExists(fileTarget) == true and fileOpen(fileTarget)) or false
		
		if load_file then
		
			local file_size = fileGetSize(load_file)
			local file_data = fileRead(load_file, file_size)
			
			-- // Recording part
			local run_lines = tas.ambatublou(file_data, "+run", "-run")
			
			if run_lines then
				local run_data = split(run_lines, "\n")
				
				if run_data and type(run_data) == "table" and #run_data > 1 then
				
					tas.data = {}
					
					for i=1, #run_data do
					
						local att = split(run_data[i], "|")
						
						local p = split(att[2], ",") 
						p[1], p[2], p[3] = tonumber(p[1]), tonumber(p[2]), tonumber(p[3]) 
						
						local r = split(att[3], ",") 
						r[1], r[2], r[3] = tonumber(r[1]), tonumber(r[2]), tonumber(r[3]) 
						
						local v = split(att[4], ",") 
						v[1], v[2], v[3] = tonumber(v[1]), tonumber(v[2]), tonumber(v[3]) 
						
						local rv = split(att[5], ",") 
						rv[1], rv[2], rv[3] = tonumber(rv[1]), tonumber(rv[2]), tonumber(rv[3]) 
						
						local n = {}
						
						local nos_returns = split(att[8], ",")
						nos_returns[1], nos_returns[2], nos_returns[3] = tonumber(nos_returns[1]), tonumber(nos_returns[2]), tonumber(nos_returns[3])
						
						if #nos_returns > 1 then 
							n = {c = nos_returns[1], l = nos_returns[2], a = (nos_returns[3] == 1)}
						else
							n = nil
						end
						
						local keys
						if att[9] then
							keys = split(att[9], ",")
						end
						
						table.insert(tas.data, {tick = tonumber(att[1]), p = p, r = r, v = v, rv = rv, h = tonumber(att[6]), m = tonumber(att[7]), n = n, k = keys})
						
					end
				end
			end
			-- //
			
			fileClose(load_file)
			
			tas.prompt("[TAS] ##File '$$"..args[1]..".tas##' has been loaded! ($$"..tostring(#tas.data).." ##frames)", 255, 255, 100)
			
		else
		
			tas.prompt("[TAS] ##Loading record failed, file does not $$exist##!", 255, 100, 100) 
			return
			
		end
	
	-- // Clear all data.
	elseif cmd == tas.registered_commands.clear_all then
	
		if tas.var.recording then tas.prompt("[TAS] ##Clearing all data failed, stop $$recording ##first!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("[TAS] ##Clearing all data failed, stop $$playbacking ##first!", 255, 100, 100) return end
	
		tas.data = {}
		
		tas.prompt("[TAS] ##Cleared everything.", 255, 100, 255)
		
	-- // Debugging
	elseif cmd == tas.registered_commands.debug then
	
		tas.settings.debugging = not tas.settings.debugging
		
		local status = (tas.settings.debugging == true) and "ENABLED" or "DISABLED"
		
		tas.prompt("[TAS] ##Debugging is now: $$".. tostring(status), 255, 100, 255)
	end
end

-- // Playbacking
function tas.render_playback()

	local vehicle = tas.cveh(localPlayer)
	
	if vehicle and not isPedDead(localPlayer) then
	
		local current_tick = getTickCount()
		local real_time = (current_tick - tas.var.start_tick)
		local inbetweening = 0

		if tas.settings.playbackInterpolation then
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
			
			inbetweening = tas.clamp(0, (real_time - tas.var.tick_1) / (tas.var.tick_2 - tas.var.tick_1), 1)
		else
			local limit = #tas.data - 1
			tas.var.play_frame = tas.var.play_frame + 1
			
			if tas.var.play_frame > limit then 
				tas.var.play_frame = limit 
				if tas.settings.stopPlaybackFinish then
					executeCommandHandler(tas.registered_commands.playback)
					return
				end
			end
		end
		
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
		if frame_data.k then
			for k,v in pairs(tas.registered_keys) do
				for _,h in ipairs(frame_data.k) do
					if k == h then
						setPedControlState(localPlayer, v, true)
					end
				end
			end
		end
	
	else
		
		removeEventHandler("onClientRender", root, tas.render_playback)
		tas.var.playbacking = false
		tas.resetBinds()
		
		tas.prompt("[TAS] ##Playbacking stopped due to an error!", 255, 100, 100)
			
	end
end

-- // Drawing debug
function tas.dxDebug()
	if tas.settings.debugging then
		for i=1, #tas.data do
			local x, y, z = unpack(tas.data[i].p)
			dxDrawLine3D(x, y, z-1, x, y, z+1, tocolor(255, 0, 0, 255), 5)
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
	if type(text) ~= "string" then return end
	iprint(string.gsub(string.gsub(text, "%#%#", ""), "%$%$", ""))
end

-- // Useful
function tas.lerp(a, b, t)
	return a + t * (b - a)
end

-- // Keep value between min and max
function tas.clamp(st, v, fn)
	return math.max(st, math.min(v, fn))
end

local pi = 3.1415926535898
-- // thanks chatgpt XD (CsaWee knows)
function tas.lerp_angle(start_angle, end_angle, progress)
    local start_angle = math.rad(start_angle)
    local end_angle = math.rad(end_angle)
    if math.abs(end_angle - start_angle) > pi then
        if end_angle > start_angle then
            start_angle = start_angle + 2*pi
        else
            end_angle = end_angle + 2*pi
        end
    end
    local angle = (1 - progress) * start_angle + progress * end_angle
    return math.deg(angle)
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
function tas.cveh(player)
	local vehicle = getPedOccupiedVehicle(player)
	if vehicle and getVehicleController(vehicle) == player then
		return vehicle
	end
	return false
end

-- // Split by 2 strings
function tas.ambatublou(str, st, nd)
	local _, starter = string.find(str, st)
	local ender = string.find(str, nd)
	if starter and ender then
		return string.sub(str, starter+1, ender-1)
	end
end

-- // Wrapper for tocolor
function tocolor(r, g, b, a)
	return b + g * 256 + r * 256 * 256 + (a or 255) * 256 * 256 * 256
end
