--[[
		* TAS - Recording Tool by chris1384 @2020
		* version 1.4
--]]

-- // the root of your problems
local tas = {
	-- // hardcoded variables, do not edit
	var = 	{
		record_tick = 0, -- used to store frame ticks for smooth playback. it's associated with 'playbackInterpolation'
		tick_1 = 0, -- last frame tick
		tick_2 = 0, -- next frame tick (used for interpolation)
		play_frame = 0, -- used for table indexing
		
		recording = false,
		recording_fbf = false, -- [UNUSED]
		fbf_switch = 0, -- [UNUSED]
		
		rewinding = false, -- [UNUSED]
		
		playbacking = false, -- magic happening
		
		fps = getFPSLimit() -- current fps of the user, can change during recording or when you're starting a new one
	},
			
	data = {}, -- run data
	warps = {}, -- warps
	entities = {}, -- [UNUSED]
	
	settings = 	{
		-- // General
		startPrompt = true, -- show resource initialization text on startup
		promptType = 1, -- [UNUSED] how action messages should be rendered. 0: none, 1: chatbox (default), 2: dxText (useful if server uses wrappers)
		
		trigger_mapStart = false, -- start recording on map start. if there's data found, switch to automatic playback instead
		stopPlaybackFinish = true, -- prevent freezing the position on last frame while playbacking
		
		usePrivateFolder = true, 
		--[[
			save or load all .tas files from the private mods folder (MTA:SA/mods/deathmatch/priv/.../tas). 
		 	set this to false if you want to use the general folder (MTA:SA/mods/deathmatch/resources/tas)
		]]
		
		useWarnings = true, -- restrict the player from doing mistakes. if it gets annoying, set this to false
		-- //
		
		
		-- // Warp Settings
		warpDelay = 500, -- time until the vehicle resumes from loading a warp
		resumeDelay = 1500, -- time until the vehicle resumes from the resume command
		rewindingDelay = 0, -- [UNUSED] time until the vehicle resumes from rewinding
		
		keepWarpData = false, -- keep all warps whenever you're starting a new run, keep this as 'false' as loading warps from previous runs can have unexpected results
		keepUnrecordedWarps = true, -- keep the warps that have been saved prior to the active recording state. setting this to false can have undesired effects while gameplaying. it's associated with 'keepWarpData'
		saveWarpData = true, -- save warp data to .tas files
		-- //
		
		
		-- // Record Settings
		precautiousRecording = true, 
		--[[ 
			~STILL NEEDS TESTING~
			CURRENT BUGS: tick can return -nan(ind) or negative values, the function can end up in a loop, might screw up teleportation scripts, warp timer may interfere.
			uses the newly introduced function that optimizes the run on the go. it checks for lagspikes every frame and recorrects the ticks from the previous 2 frames so it can be played back smoothly.
			DO NOT RECORD WITH FPS HIGHER THAN 51, IT CAN CAUSE MASSIVE BUGS!!!
		]]
		-- //
		
		
		-- // Playback Settings
		playbackPreRender = false, 
		--[[
			use the preRender event instead of the regular one. this can affect the position of a vehicle whenever it's intersecting with an object at high speed.
			by setting this to true, you can essentially avoid any extra movement at the final frame, meaning what has been recorded previously, will be played back without any imperfections. 
			unfortunately, ped position rendering is done in a separate processing order and might look out of place when playbacking.
		]]
		
		playbackInterpolation = true, -- interpolate the movement between frames for a smoother gameplay (can get jagged with framedrops)
		playbackSpeed = 1, -- change playback speed
		
		adaptiveInterpolation = false, -- [UNUSED] interpolate the frames as usual unless there's a huge lagspike, therefore, freeze to that frame. this should be considered as experimental.
		adaptiveThreshold = 6, -- [UNUSED] minimum of miliseconds 'freezed' that should be considered as lagspike. 'adaptiveInterpolation' must be set to 'true' for this to work
		
		useMacros = false, 
		--[[ 	
			use only keybinds while playbacking; position, rotation, velocity, health, nos and model recorded won't be used with helping of the run.
			please disable 'playbackInterpolation' or set 'playbackSpeed' to 1 for this to work properly [UNSURE]
			keep in mind that any lagspike can severely affect the playback. for that, use adaptiveInterpolation. [UNUSED]
			not recommended while showcasing maps and it's mainly used for debugging
		]]
		
		allowPlaybackRewinding = false, -- [UNUSED] enable the rewind function during playbacking
		-- //
		
		
		-- // Debugging Settings
		debugging = {
			level = 0,
			--[[
				set the debug level for TAS. the value can be:
				0. disabled
				1. basic (key controls only, convenient for tutorial runs)
				2. advanced (key controls, pathway and (chat) info)
				3. thorough (controls, pathway and full info about frames [LAGGY MESS])
			]]
			offsetX = 0, -- offset for hud
			
			frameSkipping = 15, -- optimize the pathway when you're not playbacking
			
			detectGround = false, -- tell TAS to capture whenever the wheels from the vehicle is touching something. probably best to use it in debugging.
		},
		-- //
		
	},
	timers = {}, -- warp load, resume timer, warning timers etc.
}
			
-- // Registered commands (edit to your liking)
tas.registered_commands = {	
	record = "record",
	record_frame = "recordf", -- [UNUSED]
	playback = "playback",
	save_warp = "rsw",
	load_warp = "rlw",
	delete_warp = "rdw",
	switch_record = "switchr", -- [UNUSED]
	next_frame = "nf", -- [UNUSED]
	previous_frame = "pf", -- [UNUSED]
	load_record = "loadr",
	save_record = "saver",
	resume = "resume",
	seek = "seek",
	debug = "debugr",
	autotas = "autotas",
	clear_all = "clearall",
	cvar = "tascvar",
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
local isVehicleWheelOnGround = isVehicleWheelOnGround
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
local getPedControlState = getPedControlState
local setPedControlState = setPedControlState

local dxDrawText = dxDrawText
local dxDrawLine3D = dxDrawLine3D

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
local math_ceil = math.ceil
local math_sqrt = math.sqrt

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
		tas.prompt("Recording Tool $$v1.4 ##by #FFAAFFchris1384 ##has started!", 255, 100, 100)
		tas.prompt("Type $$/tashelp ##for commands!", 255, 100, 100)
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

-- // Update FPS variable while recording
function tas.changeFPSEvent(_, _, _, _, _, fps)
    tas.var.fps = fps
end
addDebugHook("postFunction", tas.changeFPSEvent, {"setFPSLimit"})

-- // Another cancellation event
function tas.minimizeEvent()
	if tas.var.recording then
		removeEventHandler("onClientPreRender", root, tas.render_record)
		tas.var.recording = false
		tas.prompt("Recording stopped due to the minimize event! ($$#"..tostring(#tas.data).." ##frames)", 255, 100, 100)
	end
end
addEventHandler("onClientMinimize", root, tas.minimizeEvent)

-- // Event Commands
function tas.commands(cmd, ...) 

	local args = {...}
	
	local vehicle = tas.cveh(localPlayer)
	
	-- // Record
	if cmd == tas.registered_commands.record then
		
		if not vehicle then tas.prompt("Recording failed, get a $$vehicle ##first!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("Recording failed, stop $$playbacking ##first!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Recording failed, please wait for the resume trigger!", 255, 100, 100) return end
		
		if tas.settings.useWarnings then
			if not tas.var.recording and not tas.timers.warnRecord then
				tas.timers.warnRecord = setTimer(function() tas.timers.warnRecord = nil end, 5000, 1)
				if #tas.data > 0 then
					tas.prompt("Are you sure you want to start a $$new ##recording? Use $$/record ##again to proceed.", 255, 100, 100)
					return 
				elseif #tas.data < 1 and #tas.warps > 0 then
					if not tas.settings.keepUnrecordedWarps then
						tas.prompt("Existing warps found, are you sure you want to $$start ##recording? Use $$/record ##again to proceed.", 255, 100, 100)
						return 
					end
				end
			end
		end
		
		tas.timers.warnRecord = nil
		
		if tas.var.recording then
		
			if tas.timers.load_warp then tas.prompt("Stopping record failed, please wait a bit!", 255, 100, 100) return end
			
			removeEventHandler("onClientPreRender", root, tas.render_record)
			tas.var.recording = false
			
			tas.prompt("Recording stopped! ($$#"..tostring(#tas.data).." ##frames)", 100, 255, 100)
		else
			tas.data = {}
			
			if not tas.settings.keepWarpData then
				tas.warps = {}
			end
			
			tas.var.recording = true
			tas.var.record_tick = getTickCount()
			tas.var.fps = getFPSLimit()
			addEventHandler("onClientPreRender", root, tas.render_record)
			
			tas.prompt("Recording frames..", 100, 255, 100)
		end
		
	-- // Playback
	elseif cmd == tas.registered_commands.playback then
	
		if not vehicle then tas.prompt("Playbacking failed, get a $$vehicle ##first!", 255, 100, 100) return end
		if #tas.data < 1 then tas.prompt("Playbacking failed, no $$recorded data ##found!", 255, 100, 100) return end
		if tas.var.recording then tas.prompt("Playbacking failed, stop $$recording ##first!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Playbacking failed, please wait for the resume trigger!", 255, 100, 100) return end
		
		if tas.var.playbacking then
			removeEventHandler((tas.settings.playbackPreRender == true and "onClientPreRender" or "onClientRender"), root, tas.render_playback)
			tas.var.playbacking = false
			tas.resetBinds()
			
			tas.prompt("Playbacking stopped!", 100, 100, 255)
		else
			addEventHandler((tas.settings.playbackPreRender == true and "onClientPreRender" or "onClientRender"), root, tas.render_playback)
			tas.var.playbacking = true
			tas.var.play_frame = 1
			tas.var.record_tick = getTickCount()
			
			if tas.settings.useMacros then
				setElementPosition(vehicle, unpack(tas.data[tas.var.play_frame].p))
				setElementRotation(vehicle, unpack(tas.data[tas.var.play_frame].r))
				setElementVelocity(vehicle, unpack(tas.data[tas.var.play_frame].v))
				setElementAngularVelocity(vehicle, unpack(tas.data[tas.var.play_frame].rv))
			end
			
			tas.prompt("Playbacking started!", 100, 100, 255)
		end
	
	-- // Save Warp
	elseif cmd == tas.registered_commands.save_warp then
	
		if not vehicle then tas.prompt("Saving warp failed, get a $$vehicle ##first!", 255, 100, 100) return end
		if tas.timers.load_warp then tas.prompt("Saving warp failed, please wait for the $$warp ##to $$load##!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Saving warp failed, please wait for the resume trigger!", 255, 100, 100) return end
		
		local tick, p, r, v, rv, health, model, nos, keys = tas.record_state(vehicle)
		local frame = #tas.data
		
		if not tas.var.recording then
			tick, frame = nil, nil
		end
		
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
								
		tas.prompt("Warp $$#"..tostring(#tas.warps).." ##saved!", 60, 180, 255)
		
	-- // Load Warp
	elseif cmd == tas.registered_commands.load_warp then
		
		if not vehicle then tas.prompt("Loading warp failed, get a $$vehicle ##first!", 255, 100, 100) return end
		if #tas.warps == 0 then tas.prompt("Loading warp failed, no $$warps ##recorded!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("Loading warp failed, stop $$playbacking ##first!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Loading warp failed, please wait for the resume trigger!", 255, 100, 100) return end
		
		local warp_number = #tas.warps
		if args[1] ~= nil then
			warp_number = tonumber(args[1])
			if not warp_number or not tas.warps[warp_number] then
				tas.prompt("Loading warp failed, $$nonexistent ##warp index!", 255, 100, 100) return
			end
		end
		
		local w_data = tas.warps[warp_number]
		
		if tas.var.recording then
			if not w_data.tick or not w_data.frame then
				tas.prompt("Loading warp failed, warp has no $$frame ##or $$tick ##registered!", 255, 100, 100) return
			end
			
			removeEventHandler("onClientPreRender", root, tas.render_record)
			
			if w_data.tick <= tas.data[#tas.data].tick then
				for i=w_data.frame + 1, #tas.data do -- flawless
					tas.data[i] = nil
				end
			else
				tas.var.recording = false
				tas.prompt("Critical error, warp tick is $$bigger ##than last frame tick!", 255, 100, 100)
				tas.prompt("Recording stopped for safety, use $$/"..tas.registered_commands.resume.." ## to properly continue your run!", 255, 100, 100) 
			end
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
				tas.var.record_tick = getTickCount() - w_data.tick
				addEventHandler("onClientPreRender", root, tas.render_record)
			end
			
			tas.timers.load_warp = nil
			
		end, tas.settings.warpDelay, 1)
								
		tas.prompt("Warp $$#"..tostring(warp_number).." ##loaded!", 255, 180, 60)
		
	-- // Delete Warp
	elseif cmd == tas.registered_commands.delete_warp then
	
		local last_warp = #tas.warps
		
		if isCursorShowing() then return end
		if last_warp == 0 then tas.prompt("Deleting warp failed, no $$warps ##recorded!", 255, 100, 100) return end
		
		table_remove(tas.warps, last_warp)
		tas.prompt("Warp $$#"..tostring(last_warp).." ##deleted!", 255, 50, 50)
	
	-- // Resume
	elseif cmd == tas.registered_commands.resume then
	
		if not vehicle then tas.prompt("Resuming failed, get a $$vehicle ##first!", 255, 100, 100) return end
		if #tas.data < 1 then tas.prompt("Resuming failed, no $$recorded data ##found!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Resuming failed, please wait for the resume trigger!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("Resuming failed, stop $$playbacking ##first!", 255, 100, 100) return end
	
		local resume_number = #tas.data
		if args[1] ~= nil then
			resume_number = tonumber(args[1])
			if not resume_number or not tas.data[resume_number] then
				tas.prompt("Resuming failed, $$nonexistent ##record frame!", 255, 100, 100) return
			end
		end
		
		if tas.var.recording then
			removeEventHandler("onClientPreRender", root, tas.render_record)
			tas.var.recording = false
		end
		
		local resume_data = tas.data[resume_number]
		
		if resume_number ~= #tas.data then
			for i=resume_number + 1, #tas.data do
				tas.data[i] = nil
			end
		end
		
		setElementPosition(vehicle, unpack(resume_data.p))
		setElementRotation(vehicle, unpack(resume_data.r))
		
		setElementHealth(vehicle, resume_data.h)
		
		setElementFrozen(vehicle, true)
		
		if getElementModel(vehicle) ~= resume_data.m then
			setElementModel(vehicle, resume_data.m)
			triggerServerEvent("tas:onModelChange", vehicle, resume_data.m)
		end
		
		tas.timers.resume_load = setTimer(function()
		
			setElementFrozen(vehicle, false)
			
			setElementVelocity(vehicle, unpack(resume_data.v))
			setElementAngularVelocity(vehicle, unpack(resume_data.rv))
			
			setElementHealth(vehicle, resume_data.h)
			
			tas.nos(vehicle, resume_data.n)
			
			addEventHandler("onClientPreRender", root, tas.render_record)
			tas.var.recording = true
			
			tas.var.record_tick = getTickCount() - resume_data.tick
			
			tas.timers.resume_load = nil
									
		end, tas.settings.resumeDelay, 1)
		
		tas.prompt("Resumed from frame $$#"..resume_number.."##. Recording frames..", 100, 255, 100)
		
	-- // Seek
	elseif cmd == tas.registered_commands.seek then
	
		if not vehicle then tas.prompt("Seeking failed, get a $$vehicle ##first!", 255, 100, 100) return end
		if #tas.data < 1 then tas.prompt("Seeking failed, no $$recorded data ##found!", 255, 100, 100) return end
		if tas.var.recording or tas.timers.resume_load then tas.prompt("Seeking failed, stop $$recording ##first!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Seeking failed, please wait for the resume trigger!", 255, 100, 100) return end
		
		local seek_number = 1
		if args[1] ~= nil then
			seek_number = tonumber(args[1])
			if not seek_number or not tas.data[seek_number] or seek_number < 1 or seek_number > #tas.data then
				tas.prompt("Seeking failed, $$nonexistent ##record frame!", 255, 100, 100) return
			end
		end
		
		if not tas.var.playbacking then
			tas.var.playbacking = true
			addEventHandler((tas.settings.playbackPreRender == true and "onClientPreRender" or "onClientRender"), root, tas.render_playback)
		end
		
		tas.var.play_frame = seek_number
		tas.var.tick_1 = tas.data[tas.var.play_frame].tick
		tas.var.tick_2 = tas.data[tas.var.play_frame+1].tick
		tas.var.record_tick = getTickCount() - (tas.data[seek_number].tick / tas.settings.playbackSpeed)
		
		if tas.settings.useMacros then
			setElementPosition(vehicle, unpack(tas.data[tas.var.play_frame].p))
			setElementRotation(vehicle, unpack(tas.data[tas.var.play_frame].r))
			setElementVelocity(vehicle, unpack(tas.data[tas.var.play_frame].v))
			setElementAngularVelocity(vehicle, unpack(tas.data[tas.var.play_frame].rv))
		end
		
		tas.prompt("Seek to frame $$#"..seek_number.."##.", 100, 100, 255)
	
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
			tas.prompt("Saving failed, please specify a $$name ##for your file!", 255, 100, 100) 
			tas.prompt("Example: $$/"..tas.registered_commands.save_record.." bbw", 255, 100, 100) 
			return 
		end
		if #tas.data == 0 then tas.prompt("Saving failed, no $$data ##recorded!", 255, 100, 100) return end
		
		local isPrivated = (tas.settings.usePrivateFolder == true and "@") or ""
		local fileTarget = isPrivated .."saves/"..args[1]..".tas"
		
		if fileExists(fileTarget) then tas.prompt("Saving failed, file with the same name $$already ##exists!", 255, 100, 100) return end
		
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
				
				if run.n then
					local active = ((run.n.a == true) and "1") or "0"
					nos = tostring(run.n.c)..","..tostring(tas.float(run.n.l))..",".. active
				end
				
				local keys = ""
				if run.k then
					keys = table_concat(run.k, ",")
				end
				
				fileWrite(save_file, string_format("%d|%.04f,%.04f,%.04f|%.04f,%.04f,%.04f|%.04f,%.04f,%.04f|%.04f,%.04f,%.04f|%d|%d|%s|%s", run.tick, run.p[1], run.p[2], run.p[3], run.r[1], run.r[2], run.r[3], run.v[1], run.v[2], run.v[3], tas.float(run.rv[1]), tas.float(run.rv[2]), tas.float(run.rv[3]), run.h, run.m, nos, keys).."\n")
			end
			
			fileWrite(save_file, "-run\n")
			-- //
			
			-- // Warps part
			if #tas.warps > 0 and tas.settings.saveWarpData then
				fileWrite(save_file, "+warps\n")
				for i=1, #tas.warps do
				
					local warp = tas.warps[i]
					local nos = "-1"
					
					if warp.n then
						local active = ((warp.n.a == true) and "1") or "0"
						nos = tostring(warp.n.c)..","..tostring(tas.float(warp.n.l))..",".. active
					end
					
					if warp.tick then
						fileWrite(save_file, string_format("%d|%d|%.04f,%.04f,%.04f|%.04f,%.04f,%.04f|%.04f,%.04f,%.04f|%.04f,%.04f,%.04f|%d|%d|%s", warp.frame, warp.tick, warp.p[1], warp.p[2], warp.p[3], warp.r[1], warp.r[2], warp.r[3], warp.v[1], warp.v[2], warp.v[3], tas.float(warp.rv[1]), tas.float(warp.rv[2]), tas.float(warp.rv[3]), warp.h, warp.m, nos).."\n")
					end
					
				end
				fileWrite(save_file, "-warps")
			end
			-- //
			
			fileClose(save_file)
			
			tas.prompt("Your run has been saved to 'saves/"..args[1]..".tas'", 255, 255, 100)
		end
	
	-- // Load Recording
	elseif cmd == tas.registered_commands.load_record then
	
		if tas.var.recording then tas.prompt("Loading record failed, stop $$recording ##first!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("Loading record failed, stop $$playbacking ##first!", 255, 100, 100) return end
		if tas.timers.load_warp then tas.prompt("Loading record failed, wait for the $$warp ##to $$load##!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Loading record failed, wait for the $$resume ##process to finish!", 255, 100, 100) return end
		
		local isPrivated = (tas.settings.usePrivateFolder == true and "@") or ""
		local fileTarget = isPrivated .."saves/"..args[1]..".tas"
	
		if args[1] == nil then 
			tas.prompt("Loading record failed, please specify the $$name ##of your file!", 255, 100, 100) 
			tas.prompt("Example: $$/"..tas.registered_commands.load_record.." od3", 255, 100, 100) 
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
			
			-- // Warps part
			local warp_lines = tas.ambatublou(file_data, "+warps", "-warps")
			
			if warp_lines then
				local warp_data = split(warp_lines, "\n")
				if warp_data and type(warp_data) == "table" and #warp_data > 1 then
				
					tas.warps = {}
					
					for i=1, #warp_data do
					
						local att = split(warp_data[i], "|")
						
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
			
			tas.prompt("File '$$"..args[1]..".tas##' has been loaded! ($$"..tostring(#tas.data).." ##frames / $$"..tostring(#tas.warps).." ##warps)", 255, 255, 100)
			
		else
		
			tas.prompt("Loading record failed, file does not $$exist##!", 255, 100, 100) 
			return
			
		end
	
	-- // Auto-TAS
	elseif cmd == tas.registered_commands.autotas then
	
		tas.settings.trigger_mapStart = not tas.settings.trigger_mapStart
		
		local status = (tas.settings.trigger_mapStart == true) and "ENABLED" or "DISABLED"
		
		tas.prompt("Auto-TAS is now: $$".. tostring(status), 255, 100, 255)
	
	-- // Clear all data.
	elseif cmd == tas.registered_commands.clear_all then
	
		if tas.var.recording then tas.prompt("Clearing all data failed, stop $$recording ##first!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("Clearing all data failed, stop $$playbacking ##first!", 255, 100, 100) return end
		if tas.timers.load_warp then tas.prompt("Clearing all data failed, wait for the $$warp ##to $$load##!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Clearing all data failed, wait for the $$resume ##process to finish!", 255, 100, 100) return end
		if #tas.data == 0 and #tas.warps == 0 then tas.prompt("Nothing to clear.", 255, 100, 100) return end
		
		if tas.settings.useWarnings then
			if #tas.data > 0 and not tas.timers.warnClear then
				tas.timers.warnClear = setTimer(function() tas.timers.warnClear = nil end, 5000, 1)
				tas.prompt("Are you sure you want to $$clear ##everything? Use $$/"..tas.registered_commands.clear_all.." ##again to proceed.", 255, 100, 100)
				return 
			end
		end
		
		tas.timers.warnClear = nil
		
		tas.data = {}
		tas.warps = {}
		
		tas.prompt("Cleared all data.", 255, 100, 255)
		
	-- // Debugging
	elseif cmd == tas.registered_commands.debug then
	
		if args[1] == nil then tas.prompt("Syntax: $$/"..tas.registered_commands.debug.." [0-3]", 255, 100, 100) return end
		
		local debug_number = tonumber(args[1])
		
		if not debug_number then tas.prompt("Setting debug failed, syntax is: $$/"..tas.registered_commands.debug.." [0-3]", 255, 100, 100) return end
		if debug_number > 3 then tas.prompt("Setting debug failed, levels are from $$0 ##to $$3 ##only!", 255, 100, 100) return end
		
		if debug_number == 1 then
			tas.settings.debugging.offsetX = 60
		elseif debug_number >= 2 then
			tas.settings.debugging.offsetX = 120
		end
		
		tas.settings.debugging.level = debug_number
		
		tas.prompt("Debugging level is now set to: $$".. tostring(debug_number), 255, 100, 255)
		
	-- // Change settings
	elseif cmd == tas.registered_commands.cvar then
	
		if tas.var.recording then tas.prompt("Setting cvar failed, stop $$recording ##first!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("Setting cvar failed, stop $$playbacking ##first!", 255, 100, 100) return end
		if tas.timers.load_warp then tas.prompt("Setting cvar failed, wait for the $$warp ##to $$load##!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Setting cvar failed, wait for the $$resume ##process to finish!", 255, 100, 100) return end
		
		local value_type = args[1]
		local key = args[2]
		local value = args[3]
		
		if not value_type then tas.prompt("Setting cvar failed, syntax is: $$/"..tas.registered_commands.cvar.." type key value", 255, 100, 100) return end 
		
		if not key and value_type == "show" then
			for k,v in pairs(tas.settings) do
				if type(v) ~= "table" then
					tas.prompt(tostring(k).. ": "..tostring(v), 255, 100, 255)
				end
			end
			return
		end
		
		if key and value then
		
			if value_type == "number" then
				value = tonumber(value)
			elseif value_type == "bool" then
				value = (value == "true")
			elseif value_type == "string" then
				value = tostring(value)
			end
			
			if tas.settings[key] ~= nil then
				tas.settings[key] = value
				tas.prompt("Changed $$"..key.." ##value to $$"..tostring(value), 255, 100, 255) 
			else
				tas.prompt("Setting cvar failed, setting key does not exist!", 255, 100, 100) 
				return
			end
		else
			tas.prompt("Setting cvar failed, missing arguments (key, value)!", 255, 100, 100) 
			return
		end
		
	-- // Show Help
	elseif cmd == tas.registered_commands.help then
		tas.prompt("Commands List:", 255, 100, 100)
		tas.prompt("/"..tas.registered_commands.record.." $$| ##/"..tas.registered_commands.playback.." $$- ##start $$| ##playback your record", 255, 100, 100)
		tas.prompt("/"..tas.registered_commands.save_warp.." $$| ##/"..tas.registered_commands.load_warp.." $$| ##/"..tas.registered_commands.delete_warp.." $$- ##save $$| ##load $$| ##delete a warp", 255, 100, 100)
		tas.prompt("/"..tas.registered_commands.resume.." $$| ##/"..tas.registered_commands.seek.." $$- ##resume $$| ##seek from a frame", 255, 100, 100)
		tas.prompt("/"..tas.registered_commands.save_record.." $$| ##/"..tas.registered_commands.load_record.." $$- ##save $$| ##load a TAS file", 255, 100, 100)
		tas.prompt("/"..tas.registered_commands.autotas.." $$- ##toggle automatic record/playback", 255, 100, 100)
		tas.prompt("/"..tas.registered_commands.clear_all.." $$- ##clear all cached data", 255, 100, 100)
		tas.prompt("/"..tas.registered_commands.debug.." $$- ##toggle debugging", 255, 100, 100)
	end
end

-- // Recording
function tas.render_record(deltaTime)

	local vehicle = tas.cveh(localPlayer)
	
	if vehicle then
	
		local total_frames = #tas.data
	
		local tick, p, r, v, rv, health, model, nos, keys, ground = tas.record_state(vehicle)
		
		local previous_frame = tas.data[total_frames]
		
		if previous_frame and tas.settings.precautiousRecording then
			
			local half = 0.5
			local fps_to_ms = math_ceil(1000 / tas.var.fps)
			
			if deltaTime >= fps_to_ms * 1.5 then

				local x, y, z = unpack(p)
				local x2, y2, z2 = unpack(previous_frame.p)
				local segment_distance = tas.dist3D(x, y, z, x2, y2, z2)

				if segment_distance < 300 then
				
					local vx, vy, vz = unpack(previous_frame.v)
					local kmh = tas.dist3D(0, 0, 0, vx, vy, vz)
					
					if kmh > 0 then
					
						tas.data[total_frames].tick = math_ceil(previous_frame.tick - fps_to_ms + (segment_distance / kmh) * fps_to_ms)
						tick = tas.data[total_frames].tick + fps_to_ms
						
						tas.var.record_tick = getTickCount() - tick
						
						if tas.settings.debugging.level >= 2 then
							tas.data[total_frames].fixed = true
							tas.prompt("Lag detected, rewriting previous ticks..", 255, 150, 0)
						end
					
					end
				end
			end
			
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
			g = ground,
		})
								
	else
	
		removeEventHandler("onClientPreRender", root, tas.render_record)
		tas.var.recording = false
		
		tas.prompt("Recording stopped due to an error! ($$#"..tostring(#tas.data).." ##frames)", 255, 100, 100)
					
	end
end

-- // Recording vehicle state
function tas.record_state(vehicle, ped)

	if vehicle then
	
		local current_tick = getTickCount()
		local real_time = current_tick - tas.var.record_tick
	
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
		
		local keys = nil
		for k in pairs(tas.registered_keys) do
			if getKeyState(k) then
				if not keys then keys = {} end
				table_insert(keys, k)
			end
		end
		
		local ground = nil
		if tas.settings.debugging.detectGround then
			for i=0,3 do
				if isVehicleWheelOnGround(vehicle, i) then
					ground = true
					break
				end
			end
		end
		
		return real_time, p, r, v, rv, health, model, nos, keys, ground
					
	end
end

-- // Playbacking
function tas.render_playback()

	local vehicle = tas.cveh(localPlayer)
	
	if vehicle and not isPedDead(localPlayer) then
	
		local current_tick = getTickCount()
		local real_time = (current_tick - tas.var.record_tick) * tas.settings.playbackSpeed
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
		
		local frame_data = tas.data[tas.var.play_frame]
		local frame_data_next = tas.data[tas.var.play_frame+1]
		
		if not tas.settings.useMacros then
		
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
			
		end
		
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
		
		removeEventHandler((tas.settings.playbackPreRender == true and "onClientPreRender" or "onClientRender"), root, tas.render_playback)
		tas.var.playbacking = false
		tas.resetBinds()
		
		tas.prompt("Playbacking stopped due to an error!", 255, 100, 100)
			
	end
end

local screenW, screenH = guiGetScreenSize()

-- // Drawing debug
function tas.dxDebug()

	local offsetX = tas.settings.debugging.offsetX
	
	if tas.settings.debugging.level >= 1 then
		
		tas.dxKey("W", screenW/2-offsetX, screenH-200, 40, 40, getPedControlState(localPlayer, "accelerate") and tocolor(60, 255, 60, 255))
		tas.dxKey("S", screenW/2-offsetX, screenH-200+44, 40, 40, getPedControlState(localPlayer, "brake_reverse") and tocolor(255, 150, 50, 255))
		tas.dxKey("A", screenW/2-offsetX-44, screenH-200+44, 40, 40, getPedControlState(localPlayer, "vehicle_left") and tocolor(220, 220, 50, 255))
		tas.dxKey("D", screenW/2-offsetX+44, screenH-200+44, 40, 40, getPedControlState(localPlayer, "vehicle_right") and tocolor(220, 220, 50, 255))
		tas.dxKey("FIRE", screenW/2-offsetX-64, screenH-200+88, 60, 40, (getPedControlState(localPlayer, "vehicle_fire") or getPedControlState(localPlayer, "vehicle_secondary_fire")) and tocolor(60, 200, 255, 255))
		tas.dxKey("SPACE", screenW/2-offsetX, screenH-200+88, 160, 40, getPedControlState(localPlayer, "handbrake") and tocolor(255, 60, 60, 255))
		tas.dxKey("ᐱ", screenW/2-offsetX+120, screenH-200, 40, 40, getPedControlState(localPlayer, "steer_forward") and tocolor(255, 80, 255, 255))
		tas.dxKey("ᐯ", screenW/2-offsetX+120, screenH-200+44, 40, 40, getPedControlState(localPlayer, "steer_back") and tocolor(255, 80, 255, 255))
		
	end
	
	if tas.settings.debugging.level >= 2 then
	
		local recording_extra = (tas.timers.load_warp ~= nil and "(LOADING WARP..)") or (tas.timers.resume_load ~= nil and "(RESUMING..)") or ""
	
		tas.dxText("Recording: ".. (tas.var.recording == true and "#64FF64ENABLED" or "#FF6464DISABLED") .. " #FFFFFF" .. recording_extra, screenW/2-offsetX+170, screenH-200, 0, 0, 1)
		tas.dxText("Playbacking: ".. (tas.var.playbacking == true and "#64FF64ENABLED" or "#FF6464DISABLED"), screenW/2-offsetX+170, screenH-200+18, 0, 0, 1)
		
		tas.dxText("Total Frames: #FFAAFF#".. tostring(#tas.data), screenW/2-offsetX+170, screenH-200+18*3, 0, 0, 1)
		tas.dxText("Total Warps: #00FFFF#".. tostring(#tas.warps), screenW/2-offsetX+170, screenH-200+18*4, 0, 0, 1)
		tas.dxText("Playback Frame: #6464FF#".. tostring(tas.var.play_frame), screenW/2-offsetX+170, screenH-200+18*5, 0, 0, 1)
		
		tas.pathWay()
	end
end

function tas.pathWay()

	if tas.settings.debugging.level == 2 then
	
		local frameSkipping = (tas.var.playbacking == true and 1) or tas.settings.debugging.frameSkipping
		local startFrame = (tas.var.playbacking == true and tas.var.play_frame + 2) or 1
		local endFrame = (tas.var.playbacking == false and #tas.data - frameSkipping - 1) or math.min(tas.var.play_frame + tas.var.fps * 3, #tas.data - frameSkipping - 1)
		
		for i = startFrame, endFrame, frameSkipping do
			if tas.data[i] and tas.data[endFrame] then
				local x, y, z = unpack(tas.data[i].p)
				local x2, y2, z2 = unpack(tas.data[i + frameSkipping].p)
				local ground = (tas.data[i].g == true and tocolor(150, 150, 150, 150)) or tocolor(255, 0, 0, 150)
				
				dxDrawLine3D(x, y, z, x2, y2, z2, ground, 5)
			end
		end
		
	elseif tas.settings.debugging.level == 3 then
	
		for i=2, #tas.data - 1 do
			local x, y, z = unpack(tas.data[i].p)
			local vx, vy, vz = unpack(tas.data[i].v)
			local fixed = (tas.data[i].fixed == true and tocolor(0, 255, 0, 255)) or tocolor(255, 0, 0, 255)
			dxDrawLine3D(x, y, z-1, x, y, z+1, fixed, 5)
			
			local swX, swY = getScreenFromWorldPosition(x, y, z+1.1, 2)
			if swX and swY then
				dxDrawText(tostring(i).." "..tostring(tas.data[i].tick).." "..tostring(tas.data[i].tick - tas.data[i-1].tick), swX, swY, swX, swY, fixed, 1, "arial", "center", "center")
			end
			
			dxDrawLine3D(x, y, z, x+vx, y+vy, z+vz, tocolor(0, 255, 255, 100), 5)
			local swX, swY = getScreenFromWorldPosition(x+vx, y+vy, z+vz+0.1, 2)
			if swX and swY then
				dxDrawText(tas.dist3D(0, 0, 0, vx, vy, vz), swX, swY, swX, swY, tocolor(0, 255, 255, 255), 1, "arial", "center", "center")
			end
			
			local nx, ny, nz = unpack(tas.data[i+1].p)
			
			local mx, my, mz = tas.middle3D(x, y, z, nx, ny, nz)
			local swX, swY = getScreenFromWorldPosition(mx, my, mz+1.5, 2)
			if swX and swY then
				dxDrawText(tas.dist3D(x, y, z, nx, ny, nz), swX, swY, swX, swY, tocolor(0, 255, 255, 255), 1, "arial", "center", "center")
			end
			
			dxDrawLine3D(x+vx, y+vy, z+vz, nx, ny, nz, tocolor(255, 0, 255, 100), 5)
			local swX, swY = getScreenFromWorldPosition(x+vx, y+vy, z+vz+0.5, 2)
			if swX and swY then
				dxDrawText(tas.dist3D(x+vx, y+vy, z+vz, nx, ny, nz), swX, swY, swX, swY, tocolor(255, 255, 255, 255), 1, "arial", "center", "center")
			end
		end
		
	end
	
end

-- // Cute dxKeybind
function tas.dxKey(keyName, x, y, x2, y2, color)
	dxDrawRectangle(x, y, x2, y2, color or tocolor(200, 200, 200, 200))
	dxDrawText(keyName, x, y, x+x2, y+y2, tocolor(0, 0, 0, 255), 1.384, "default-bold", "center", "center")
end

-- // Cute dxText
function tas.dxText(text, x, y, x2, y2, size)
	dxDrawText(text:gsub("#%x%x%x%x%x%x", ""), x+1, y+1, x2+1, y2+1, tocolor(0,0,0,255), size, "default", "left", "top", false, false, false, true)
	dxDrawText(text, x, y, x2, y2, tocolor(255,255,255,255), size, "default", "left", "top", false, false, false, true)
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
	return outputChatBox("[TAS] #FFFFFF"..string_gsub(string_gsub(text, "%#%#", "#FFFFFF"), "%$%$", string_format("#%.2X%.2X%.2X", r, g, b)), r, g, b, true)
end

-- // Useful
function tas.lerp(a, b, t)
	return a + t * (b - a)
end

-- // Keep value between min and max
function tas.clamp(st, v, fn)
	return math_max(st, math_min(v, fn))
end

-- // Lerp angle
function tas.lerp_angle(st, nd, prog)
	local delta = (nd - st + 180) % 360 - 180
	return (st + delta * prog) % 360
end

-- // Nitro detection and modify stats (playback and load warp)
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

-- // Calculate distance 2D (faster than the mta func)
function tas.dist2D(x, y, x2, y2)
	return ((x2 - x) * (x2 - x) + (y2 - y) * (y2 - y)) ^ 0.5
end

-- // Calculate distance 3D (faster than the mta func)
function tas.dist3D(x, y, z, x2, y2, z2)
	return ((x2 - x) * (x2 - x) + (y2 - y) * (y2 - y) + (z2 - z) * (z2 - z)) ^ 0.5
end

-- // Get middle x, y ,z of a segment
function tas.middle3D(x, y, z, x2, y2, z2)
	return (x + x2)*0.5, (y + y2)*0.5, (z + z2)*0.5
end

-- // Wrapper for tocolor
function tocolor(r, g, b, a)
	return b + g * 256 + r * 256 * 256 + (a or 255) * 256 * 256 * 256
end
