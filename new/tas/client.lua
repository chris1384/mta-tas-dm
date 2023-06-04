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
		recording_fbf = false, -- [UNUSED]
		fbf_switch = 0, -- [UNUSED]
		
		rewinding = false, -- [UNUSED]
		
		loading_warp = false, -- used to restrict stopping recording when warp is loading
		
		playbacking = false, -- magic happening
			},
			
	data = {}, -- run data
	warps = {}, -- warps
	entities = {}, -- [UNUSED]
	
	settings = 	{
		startPrompt = true, -- show resource initialization text on startup
		promptType = 1, -- how action messages should be rendered. 0: none, 1: chatbox (default), 2: dxText (useful if server uses wrappers)
		
		captureFramerate = false, 
		--[[
			specify the tick target you'd want to record your run, low values might be efficient for saving but can cause jittery playbacking. this should be considered as experimental.
			please use values in miliseconds :: 1000 / FRAMERATE;
			e.g. 1000 / 51
			set to 'false' to disable it
		]]
		
		trigger_mapStart = false, -- start recording on map start. if there's data found, switch to automatic playback instead
		stopPlaybackFinish = true, -- prevent freezing the position on last frame while playbacking
		
		warpResume = 500, -- time until the vehicle resumes from loading a warp
		
		keepWarpData = false, -- keep all warps whenever you're starting a new run, keep this as 'false' as loading warps from previous runs can have unexpected results
		saveWarpData = true, -- save warp data to .tas files
		
		usePrivateFolder = true, -- save or load all .tas files from the private mods folder (MTA:SA/mods/deathmatch/priv/.../tas). 
		-- set this to false if you want to use the general folder (MTA:SA/mods/deathmatch/resources/tas)
		
		playbackSpeed = 1, -- change playback speed
		playbackInterpolation = true, -- interpolate the movement between frames for a smoother gameplay (can get jagged with framedrops)
		
		adaptiveInterpolation = false, -- [UNUSED] interpolate the frames as usual unless there's a huge lagspike, therefore, freeze to that frame. this should be considered as experimental.
		adaptiveThreshold = 6, -- [UNUSED] minimum of frames 'freezed' that should be considered as lagspike. 'adaptiveInterpolation' must be set to 'true' for this to work
		
		detectGround = false, -- [UNUSED] tell TAS to capture whenever the wheels from the vehicle is touching something. probably best to use it in debugging.
		
		debugging = false, -- show debug info
	},
	timers = {}, -- warp load, warning timers [UNUSED] etc.
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
						
--[[ 
	This part involves storing every function as local functions.
	These can be helpful for speeding up the process of registering frames, play the run and loading or saving files.
	If these ones bother you, delete them at your own risk.
]]
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
local tostring = tostring
local tonumber = tonumber

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
local table_concat = table.concat
local string_find = string.find
local string_sub = string.sub
local string_gsub = string.gsub
local string_format = string.format

-- // Local Functions End

-- // Initialization
function tas.init()

	if tas.settings.startPrompt then
		tas.prompt("[TAS] ##Recording Tool $$v1.4 ##by #FFAAFFchris1384 ##has started!", 255, 100, 100)
		tas.prompt("[TAS] ##Type $$/tashelp ##for commands!", 255, 100, 100)
	end
	
	for _,v in pairs(tas.registered_commands) do
		addCommandHandler(v, tas.commands)
	end
	
	addEventHandler("onClientRender", root, tas.dxDebug)
	
end
addEventHandler("onClientResourceStart", resourceRoot, tas.init)

-- // Termination
function tas.stop()
	tas.resetBinds()
end
addEventHandler("onClientResourceStop", resourceRoot, tas.stop)

-- // Custom Race Events
function tas.raceWrap(event)
	iprint(source, event)
	if not tas.settings.trigger_mapStart then return end
	if event == "Started" then
		if tas.var.recording or tas.var.playbacking then return end
		if #tas.data > 0 then
			executeCommandHandler(tas.registered_commands.playback)
		else
			executeCommandHandler(tas.registered_commands.record)
		end
	elseif event == "Stop" then
		if tas.var.recording then
			executeCommandHandler(tas.registered_commands.record)
		elseif tas.var.playbacking then
			executeCommandHandler(tas.registered_commands.playback)
		end
	end
end
addEvent("tas:triggerCommand", true)
addEventHandler("tas:triggerCommand", root, tas.raceWrap)

-- // Event Commands
function tas.commands(cmd, ...) 

	local args = {...}
	
	local vehicle = tas.cveh(localPlayer)
	
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
			
			if tas.settings.keepWarpData ~= true then
				tas.warps = {}
			end
			
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
	
	-- // Save Warp
	elseif cmd == tas.registered_commands.save_warp then
	
		if not vehicle then tas.prompt("[TAS] ##Saving warp failed, get a $$vehicle ##first!", 255, 100, 100) return end
		if tas.var.loading_warp then tas.prompt("[TAS] ##Saving warp failed, please wait for the $$warp ##to $$load##!", 255, 100, 100) return end
		
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
		
		local warp_number = #tas.warps
		if args[1] ~= nil then
			warp_number = tonumber(args[1])
			if not warp_number or not tas.warps[warp_number] then
				tas.prompt("[TAS] ##Loading warp failed, $$nonexistent ##warp index!", 255, 100, 100) return
			end
		end
		
		tas.var.loading_warp = true
		
		local w_data = tas.warps[warp_number]
		
		if tas.var.recording then
			removeEventHandler("onClientRender", root, tas.render_record)
		end
		
		for i=w_data.frame + 1, #tas.data do -- flawless
			tas.data[i] = nil
		end
		
		setElementPosition(vehicle, unpack(w_data.p))
		setElementRotation(vehicle, unpack(w_data.r))
		
		setElementHealth(vehicle, w_data.h)
		
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
								
		tas.prompt("[TAS] ##Warp $$#"..tostring(warp_number).." ##loaded!", 255, 180, 60)
		
	-- // Delete Warp
	elseif cmd == tas.registered_commands.delete_warp then
	
		local last_warp = #tas.warps
		
		if isCursorShowing() then return end
		if last_warp == 0 then tas.prompt("[TAS] ##Deleting warp failed, no $$warps ##recorded!", 255, 100, 100) return end
		
		table_remove(tas.warps, last_warp)
		tas.prompt("[TAS] ##Warp $$#"..tostring(last_warp).." ##deleted!", 255, 50, 50)
	
	-- // Resume
	elseif cmd == tas.registered_commands.resume then
		tas.prompt("[TAS] ##resume", 255, 50, 50)
		
	-- // Save Recording
	elseif cmd == tas.registered_commands.save_record then
	
		-- FORMAT (for nerds):
		-- +run
		-- tick|x,y,z|rx,ry,rz|vx,vy,vz|rvx,rvy,rvz|health|model|c,l,a or -1|keys
		-- -run
		
		-- +warps
		-- frame|tick|x,y,z|rx,ry,rz|vx,vy,vz|rvx,rvy,rvz|health|model|c,l,a or -1
		-- -warps
									
		if args[1] == nil then 
			tas.prompt("[TAS] ##Saving failed, please specify a $$name ##for your file!", 255, 100, 100) 
			tas.prompt("[TAS] ##Example: $$/"..tas.registered_commands.save_record.." bbw", 255, 100, 100) 
			return 
		end
		if #tas.data == 0 then tas.prompt("[TAS] ##Saving failed, no $$data ##recorded!", 255, 100, 100) return end
		
		local isPrivated = (tas.settings.usePrivateFolder == true and "@") or ""
		local fileTarget = isPrivated .."saves/"..args[1]..".tas"
		
		--if fileExists("@saves/"..args[1]..".tas") then fileDelete("@saves/"..args[1]..".tas") end
		if fileExists(fileTarget) then tas.prompt("[TAS] ##Saving failed, file with the same name $$already ##exists!", 255, 100, 100) return end
		
		local save_file = fileCreate(fileTarget)
		if save_file then
		
			-- // Header
			fileWrite(save_file, "# "..args[1]..".tas file created on "..os.date().."\n")
			fileWrite(save_file, "# Author: "..string_gsub(getPlayerName(localPlayer), "#%x%x%x%x%x%x", "").." | Frames: "..tostring(#tas.data).." | Warps: "..tostring(#tas.warps).."\n\n")
			-- //
			
			-- // Recording part
			fileWrite(save_file, "+run\n")
			
			for i=1, #tas.data do
			
				local run = tas.data[i]
				local nos = "-1"
				
				if run.n ~= nil then
					local active = ((run.n.a == true) and "1") or "0"
					nos = tostring(run.n.c)..","..tostring(tas.float(run.n.l))..",".. active
				end
				
				fileWrite(save_file, string_format("%d|%.04f,%.04f,%.04f|%.04f,%.04f,%.04f|%.04f,%.04f,%.04f|%.04f,%.04f,%.04f|%d|%d|%s|%s", run.tick, run.p[1], run.p[2], run.p[3], run.r[1], run.r[2], run.r[3], run.v[1], run.v[2], run.v[3], tas.float(run.rv[1]), tas.float(run.rv[2]), tas.float(run.rv[3]), run.h, run.m, nos, table_concat(run.k, ",")).."\n")
			end
			
			fileWrite(save_file, "-run\n")
			-- //
			
			-- // Warps part
			if #tas.warps > 0 and tas.settings.saveWarpData then
				fileWrite(save_file, "+warps\n")
				for i=1, #tas.warps do
				
					local warp = tas.warps[i]
					local nos = "-1"
					
					if warp.n ~= nil then
						local active = ((warp.n.a == true) and "1") or "0"
						nos = tostring(warp.n.c)..","..tostring(tas.float(warp.n.l))..",".. active
					end
					
					fileWrite(save_file, string_format("%d|%d|%.04f,%.04f,%.04f|%.04f,%.04f,%.04f|%.04f,%.04f,%.04f|%.04f,%.04f,%.04f|%d|%d|%s", warp.frame, warp.tick, warp.p[1], warp.p[2], warp.p[3], warp.r[1], warp.r[2], warp.r[3], warp.v[1], warp.v[2], warp.v[3], tas.float(warp.rv[1]), tas.float(warp.rv[2]), tas.float(warp.rv[3]), warp.h, warp.m, nos).."\n")
				end
				fileWrite(save_file, "-warps")
			end
			-- //
			
			fileClose(save_file)
			
			tas.prompt("[TAS] ##Your run has been saved to 'saves/"..args[1]..".tas'", 255, 255, 100)
		end
	
	-- // Load Recording
	elseif cmd == tas.registered_commands.load_record then
	
		local isPrivated = (tas.settings.usePrivateFolder == true and "@") or ""
		local fileTarget = isPrivated .."saves/"..args[1]..".tas"
	
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
						
						--[[
						local p = {loadstring("return "..att[2])()}
						local r = {loadstring("return "..att[3])()}
						local v = {loadstring("return "..att[4])()}
						local rv = {loadstring("return "..att[5])()}
						]]
						
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
			
			-- // Warps part
			local warp_lines = tas.ambatublou(file_data, "+warps", "-warps")
			
			if warp_lines then
				local warp_data = split(warp_lines, "\n")
				if warp_data and type(warp_data) == "table" and #warp_data > 1 then
				
					tas.warps = {}
					
					for i=1, #warp_data do
					
						local att = split(warp_data[i], "|")
						
						--[[
						local p = {loadstring("return "..att[3])()}
						local r = {loadstring("return "..att[4])()}
						local v = {loadstring("return "..att[5])()}
						local rv = {loadstring("return "..att[6])()}
						]]
						
						local p = split(att[3], ",") 
						p[1], p[2], p[3] = tonumber(p[1]), tonumber(p[2]), tonumber(p[3]) 
						
						local r = split(att[4], ",") 
						r[1], r[2], r[3] = tonumber(r[1]), tonumber(r[2]), tonumber(r[3]) 
						
						local v = split(att[5], ",") 
						v[1], v[2], v[3] = tonumber(v[1]), tonumber(v[2]), tonumber(v[3]) 
						
						local rv = split(att[6], ",") 
						rv[1], rv[2], rv[3] = tonumber(rv[1]), tonumber(rv[2]), tonumber(rv[3]) 
						
						local n = {}
						
						local nos_returns = split(att[9], ",")
						nos_returns[1], nos_returns[2], nos_returns[3] = tonumber(nos_returns[1]), tonumber(nos_returns[2]), tonumber(nos_returns[3])
						
						if #nos_returns > 1 then 
							n = {c = nos_returns[1], l = nos_returns[2], a = (nos_returns[3] == 1)}
						else
							n = nil
						end
						
						table.insert(tas.warps, {frame = tonumber(att[1]), tick = tonumber(att[2]), p = p, r = r, v = v, rv = rv, h = tonumber(att[7]), m = tonumber(att[8]), n = n})
					end
					
				end
			end
			-- //
			
			fileClose(load_file)
			
			tas.prompt("[TAS] ##File '$$"..args[1]..".tas##' has been loaded! ($$"..tostring(#tas.data).." ##frames / $$"..tostring(#tas.warps).." ##warps)", 255, 255, 100)
			
		else
		
			tas.prompt("[TAS] ##Loading record failed, file does not $$exist##!", 255, 100, 100) 
			return
			
		end
	
	-- // Auto-TAS
	elseif cmd == tas.registered_commands.autotas then
	
		tas.settings.trigger_mapStart = not tas.settings.trigger_mapStart
		
		local status = (tas.settings.trigger_mapStart == true) and "ENABLED" or "DISABLED"
		
		tas.prompt("[TAS] ##Auto-TAS is now: $$".. tostring(status), 255, 100, 255)
	
	-- // Clear all data.
	elseif cmd == tas.registered_commands.clear_all then
	
		if tas.var.recording then tas.prompt("[TAS] ##Clearing all data failed, stop $$recording ##first!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("[TAS] ##Clearing all data failed, stop $$playbacking ##first!", 255, 100, 100) return end
	
		tas.data = {}
		tas.warps = {}
		
		tas.prompt("[TAS] ##Cleared everything.", 255, 100, 255)
		
	-- // Debugging
	elseif cmd == tas.registered_commands.debug then
	
		tas.settings.debugging = not tas.settings.debugging
		
		local status = (tas.settings.debugging == true) and "ENABLED" or "DISABLED"
		
		tas.prompt("[TAS] ##Debugging is now: $$".. tostring(status), 255, 100, 255)
		
	-- // Show Help
	elseif cmd == tas.registered_commands.help then
		tas.prompt("[TAS] ##Commands List:", 255, 100, 100)
		tas.prompt("[TAS] ##/"..tas.registered_commands.record.." $$| ##/"..tas.registered_commands.playback.." $$- ##start $$| ##playback your record", 255, 100, 100)
		tas.prompt("[TAS] ##/"..tas.registered_commands.save_warp.." $$| ##/"..tas.registered_commands.load_warp.." $$| ##/"..tas.registered_commands.delete_warp.." $$- ##save $$| ##load $$| ##delete a warp", 255, 100, 100)
		tas.prompt("[TAS] ##/"..tas.registered_commands.save_record.." $$| ##/"..tas.registered_commands.load_record.." $$- ##save $$| ##load a TAS file", 255, 100, 100)
		tas.prompt("[TAS] ##/"..tas.registered_commands.autotas.." $$- ##toggle automatic record/playback", 255, 100, 100)
		tas.prompt("[TAS] ##/"..tas.registered_commands.clear_all.." $$- ##clear all cached data", 255, 100, 100)
	end
end

-- // Recording
function tas.render_record()

	local vehicle = tas.cveh(localPlayer)
	
	if vehicle then
	
		local tick, p, r, v, rv, health, model, nos, keys = tas.record_state(vehicle)
		
		if tas.data[#tas.data - 1] then
			if tas.settings.captureFramerate and (tas.data[#tas.data - 1].tick + tas.settings.captureFramerate) > tick then return end
		end
		
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
	
	else
	
		removeEventHandler("onClientRender", root, tas.render_record)
		tas.var.recording = false
		
		tas.prompt("[TAS] ##Recording stopped due to an error! ($$"..tostring(#tas.data).." ##frames)", 255, 100, 100)
					
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

	local vehicle = tas.cveh(localPlayer)
	
	if vehicle and not isPedDead(localPlayer) then
	
		local current_tick = getTickCount()
		local real_time = (current_tick - tas.var.start_tick) * tas.settings.playbackSpeed
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
			dxDrawLine3D(x, y, z-0.5, x, y, z+0.5, tocolor(255, 0, 0, 255), 5)
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
	return outputChatBox(string_gsub(string_gsub(text, "%#%#", "#FFFFFF"), "%$%$", string.format("#%.2X%.2X%.2X", r, g, b)), r, g, b, true)
end

-- // Useful
function tas.lerp(a, b, t)
	return a + t * (b - a)
end

-- // Keep value between min and max
function tas.clamp(st, v, fn)
	return math_max(st, math_min(v, fn))
end

-- // thanks chatgpt XD (CsaWee knows)
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
function tas.cveh(player)
	local vehicle = getPedOccupiedVehicle(player)
	if vehicle and getVehicleController(vehicle) == player then
		return vehicle
	end
	return false
end

-- // Split by 2 strings
function tas.ambatublou(str, st, nd)
	local _, starter = string_find(str, st)
	local ender = string_find(str, nd)
	if starter and ender then
		return string_sub(str, starter+1, ender-1)
	end
end

-- // Used for efficient saving
function tas.float(number)
	return math_floor( number * 1000 ) * 0.001
end

-- // Wrapper for tocolor
function tocolor(r, g, b, a)
	return b + g * 256 + r * 256 * 256 + (a or 255) * 256 * 256 * 256
end
