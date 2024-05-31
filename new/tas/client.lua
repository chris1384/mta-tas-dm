--[[
		* TAS - Recording Tool by chris1384 @2020
		* version 1.4.3
]]

-- // the root of your problems
local tas = {

	-- // hardcoded variables, do not edit
	var = 	{
		record_tick = 0, -- used to store frame ticks for smooth playback. it's associated with 'playbackInterpolation'
		tick_1 = 0, -- last frame tick
		tick_2 = 0, -- next frame tick (used for interpolation)
		play_frame = 0, -- used for table indexing
		delta = 0, -- used for adaptiveInterpolation
		
		recording = false,
		--recording_fbf = false, -- [UNUSED]
		--fbf_switch = 0, -- [UNUSED]
		
		rewinding = false, -- rewind phase
		rewind_cache = 0, -- used for slow rewind
		
		playbacking = false, -- magic happening
		
		saving_handle = nil, -- server-save handle number
		saving_percent = 0, -- server-save percentage
		
		analog_direction = 0, -- analog wrapper value
		
		fps = getFPSLimit(), -- current fps of the user, can change during recording or when you're starting a new one
		gamespeed = getGameSpeed(), -- used for slowmotion recording
		gamespeed_event = false, -- used for slowmotion recording
		
		editor = "none", 
		--[[ Editor mode, it can be:
			- none : editor_gui is inactive (resource not running or map testing - default behaviour)
			- freecam : you're currently flying in editor (uses frameSkipping for pathway = low CPU usage)
			- cursor : you're in cursor mode (dummy vehicles can be created, frameSkipping disabled)
		]]
		editor_select = false, -- selected waypoint
		editor_dummy_client = nil, -- preview dummy before getting created to the server
	},
			
	data = {}, -- run data
	warps = {}, -- warps
	entities = {}, -- [UNUSED]
	textures = {}, -- textures duuh
	
	-- // Settings incoming, these can be edited here directly or using the in-game command (/tascvar)
	settings = 	{
	
		-- // General
		startPrompt = true, -- show resource initialization text on startup
		promptType = 1, -- how action messages should be rendered. 0: none, 1: chatbox (default), 2: dxText (useful if server uses wrappers), 3: iprint (clientscript log)
		
		enableUserConfig = true, 
		--[[
			save every cvar modified in a separate file, then use it to load your next session of using TAS.
			this setting works no matter what its value is, it depends on the users config file and if they used /tascvar
			it is associated with 'usePrivateFolder', edit: HELL NO IT'S NOT LMAO
			added it from a couple of requests
		]]
		
		trigger_mapStart = false, -- [AUTO-TAS cvar] start recording on map start. if there's data found, switch to automatic playback instead
		stopPlaybackFinish = true, -- prevent freezing the position on last frame while playbacking
		
		usePrivateFolder = true, 
		--[[
			save or load all .tas files from the private mods folder (MTA:SA/mods/deathmatch/priv/.../tas). 
		 	set this to false if you want to use the general folder (MTA:SA/mods/deathmatch/resources/tas)
		]]
		
		useWarnings = true, -- restrict the player from doing mistakes. if it gets annoying, set this to false
		abortOnInvalidity = false, -- prevent TAS from loading any more lines (when using /loadr) if it finds an invalid one. you can end up with only half of the recording loaded, so keep this to false.
		
		hunterFinish = false, -- stop recording/playbacking as soon as the player has reached the hunter (model change detection). setting this to true can have undesired effects while gameplaying.
		-- //
		
		
		-- // Editor
		enableEditorMode = true, --[[
			use TAS as an editor tool to create MRT dummy vehicles or create slowbug fixes
			this also enables the record command to be bounded onto a key (default is 'R') as you would use MRT. this gets disabled when editor stops.
			disabling this also disables all of the editor features listed below.
			WARNING: this overrides the /debugr pathway
		]]
		
		editorRecordKey = "r", -- you know what it is
		editorRecordMode = "new", -- how the bounded key should behave. this can be: 'new' - start a new recording; 'resume' - resume the recording from last waypoint; 'none' - disable the keybind
		
		editorEnableDummy = true, -- enable the creation of MRT dummies
		editorDummyKey = "v", -- create vehicle dummy key
		
		editorEnableSlowbug = true, -- enable the creation of slowbug fix scripts
		editorSlowbugKey = "b", -- key to output a slowbug fixer script from the waypoint and copy to clipboard
		-- //
		
		
		-- // Analog Controls
		enableAnalog = false, -- [MASTER SWITCH] enable analog controls, compatible with console controllers
		useAnalogWrapper = false, -- keyboard analog controlling for steering. set 'enableAnalog' to true for this to work. this should be considered as experimental.
		analogSensitivity = 0.15, -- the steering increase | decrease*1.33 power while using analog control. set 'enableAnalog' to true for this to work. it's associated with 'useAnalogWrapper'
		-- //
		
		
		-- // Warp Settings
		warpDelay = 500, -- time until the vehicle resumes from loading a warp
		resumeDelay = 2000, -- time until the vehicle resumes from the resume command
		
		keepWarpData = false, -- keep all warps whenever you're starting a new run, keep this as 'false' as loading warps from previous runs can have unexpected results, but can have undesired effects while gameplaying
		saveWarpData = true, -- save warp data to .tas files
		-- //
		
		
		-- // Record Settings
		useGameSpeed = false, 
		--[[
			recalculate the ticks based on players gamespeed (slowmotion/speedup).
			this can be useful for achieving near perfect runs on precision based map parts (EoS e.g.) using slowmotion then playback as it was played normally
			maps often have gamespeed scripts integrated into them for decoration showcase, please use /tascvar to tweak it from time to time
			should be used with care, as players can get an unfair benefit (playbacking) on parts designed to be played in slowmotion.
			NB: slowmotion can affect angular velocity due to GTA:SA's air resistance implementation, which is not FPS friendly
		]]
		
		rewindingKey = "backspace", -- registered key for rewinding
		rewindingDelay = 1500, -- time in miliseconds until the vehicle resumes from rewinding; 0 - instant
		rewindingCameraReset = false, -- reset the camera position after the rewind phase
		
		antiExplode = true, -- set the vehicle health to bare minimum during rewinding/loading to prevent it from exploding. this should be used cautiously, since playbacking might return an error mid-run
		replaceBlow = true, 
		--[[ 
			prevent from blowing up the vehicle when an anti-sc is triggered, instead use the teleport method used in Overdrive 3/Aphelium 3
			it only worked during recording, now enabled during normal gameplay due to multiple requests.
			doesn't work while playbacking.
		]]
		-- //
		
		
		-- // Playback Settings
		playbackPreRender = false, 
		--[[
			use the preRender event instead of the regular one. this can affect the position of a vehicle whenever it's intersecting with an object at high speed.
			by setting this to true, you can essentially avoid any extra movement at the final frame, meaning what has been recorded previously, will be played back without any imperfections. 
			unfortunately, ped position rendering is done in a separate processing order and might look out of place when playbacking. (doesn't work using a separate render event, positions are updated in preRender)
		]]
		
		playbackInterpolation = true, -- interpolate the movement between frames for a smoother gameplay (can get jagged with framedrops)
		playbackSpeed = 1, -- change playback speed, it's associated with 'playbackInterpolation'
		
		adaptiveInterpolation = false, -- interpolate the frames as usual unless there's a huge lagspike, therefore, freeze to that frame. this should be considered as experimental.
		adaptiveThreshold = 500, -- minimum of miliseconds 'freezed' that should be considered as lagspike. 'adaptiveInterpolation' must be set to 'true' for this to work
		
		useOnlyBinds = false, 
		--[[ 	
			use only keybinds while playbacking; position, rotation, velocity, health, nos and model recorded won't be used with helping of the run.
			please disable 'playbackInterpolation' or set 'playbackSpeed' to 1 for this to work properly
			keep in mind that any lagspike can severely affect the playback. for that, use adaptiveInterpolation. [SOON]
			not recommended while showcasing maps and it's mainly used for debugging
		]]
		
		useNitroStates = true, -- check for the nitro state on every frame that has been recorded, it updates in real time but can cause visual bugs during multiplayer gameplay.
		useHealthStates = true, -- always set health to the vehicle using the stored HP value from the recording. setting this to false might cause unintended playback errors.
		useVehicleChange = true, -- check for vehicle model on every frame so it would display the correct vehicle every time.
		
		--allowPlaybackRewinding = false, -- [UNUSED] enable the rewind function during playbacking
		-- //
		
		
		-- // Debugging (uneditable in-game)
		debugging = {
			level = 0,
			--[[
				set the debug level for TAS. the value can be:
				0. disabled
				1. basic (key controls only, convenient for tutorial runs)
				2. advanced (key controls, pathway and (chat) info)
				3. thorough (controls, pathway and full info about frames [LAGGY MESS])
				
				use /debugr to toggle
			]]
			offsetX = 0, -- offset for hud
			
			frameSkipping = 15, -- optimize the pathway when you're not playbacking
			wholeFrameClipDistance = 200, -- farClipDistance for full frames, so it won't display everything.
			
			warpsRenderLevel = 3, -- at which debug-level should warps start rendering (text and marker)
			
			detectGround = false, -- tell TAS to capture whenever the wheels from the vehicle is touching something. probably best to use it in debugging.
		},
		-- //
		
	},
	timers = {}, -- warp, resume, rewind, warning timers
}
			
-- // Registered commands (edit to your liking)
tas.registered_commands = {	
	record = "record",
	--record_frame = "recordf", -- [UNUSED]
	playback = "playback",
	save_warp = "rsw",
	load_warp = "rlw",
	delete_warp = "rdw",
	--switch_record = "switchr", -- [UNUSED]
	--next_frame = "nf", -- [UNUSED]
	--previous_frame = "pf", -- [UNUSED]
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
tas.registered_keys = {}

-- // Global key mappings, to use as a fix for different keyboard layouts and avoid incompatibility
tas.key_mappings = {
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
	-- q = "vehicle_look_left",
	-- e = "vehicle_look_right",
	-- num_4 = "special_control_right",
	-- num_6 = "special_control_left",
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
local getGameSpeed = getGameSpeed

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
local getAnalogControlState = getAnalogControlState
local setAnalogControlState = setAnalogControlState
local getCursorPosition = getCursorPosition
local isCursorShowing = isCursorShowing
local getScreenFromWorldPosition = getScreenFromWorldPosition

local dxDrawText = dxDrawText
local dxDrawLine3D = dxDrawLine3D
local dxDrawImage = dxDrawImage
local dxDrawImageSection = dxDrawImageSection
local dxDrawRectangle = dxDrawRectangle

-- // Cool LUA
local ipairs = ipairs
local pairs = pairs
local unpack = unpack
local tostring = tostring
local tonumber = tonumber

-- // Cool math
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_floor = math.floor
local math_ceil = math.ceil
local screenW, screenH = guiGetScreenSize()

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
	
	tas.registered_commands.tas = "tas" -- tasception
	for _,v in pairs(tas.registered_commands) do
		addCommandHandler(v, tas.commands)
	end
	
	for bind, control in pairs(tas.key_mappings) do
		local bound_keys = getBoundKeys(control)
		if type(bound_keys) == "table" then
			for bound, _ in pairs(bound_keys) do
				if not tas.registered_keys[bound] then tas.registered_keys[bound] = {} end
				tas.registered_keys[bound].c_bind = bind
			end
		end
	end
	
	addEventHandler("onClientRender", root, tas.dxDebug, true, "low-1384")
	addEventHandler("onClientKey", root, tas.binds)
	
	tas.textures.triangle = svgCreate(40, 80, [[<svg height="40" width="40"><polygon points="0,20 40,0 40,40" style="fill:white"/></svg>]])
	
	local config_loaded = false
	
	-- // User config load, if you want to disable it entirely, delete this part >>
	if fileExists("@config.json") then
		local config_file = fileOpen("@config.json")
		if config_file then
		
			local size = fileGetSize(config_file)
			local data = fileRead(config_file, size)
			local data2table = fromJSON(data)
			
			if data2table.enableUserConfig == true then
				for key,value in pairs(data2table) do
					if tas.settings[key] ~= nil then
						tas.settings[key] = value
						config_loaded = true
					end
				end
			end
		
			fileClose(config_file)
		end
	end
	-- // << Until here 
	
	if tas.settings.startPrompt then
		tas.prompt("Recording Tool $$v1.4.3 ##by #FFAAFFchris1384 ##has started!", 255, 100, 100)
		tas.prompt("Type $$/tashelp ##for commands!", 255, 100, 100)
		
		if config_loaded then
			tas.prompt("User settings have been loaded!", 255, 100, 255)
		end
	end
	
end
addEventHandler("onClientResourceStart", resourceRoot, tas.init)

-- // Termination
function tas.stop(stoppedResource)

	local resourceName = getResourceName(stoppedResource)
	
	if stoppedResource == resource then
		tas.resetBinds()
		if getResourceFromName("editor_main") then
			exports["editor_main"]:setWorldClickEnabled(true)
		end
		
	elseif resourceName == "editor" then
		tas.var.editor = "none"

		if tas.var.editor_dummy_client and isElement(tas.var.editor_dummy_client) then
			destroyElement(tas.var.editor_dummy_client)
			tas.var.editor_dummy_client = nil
		end
		
	end
end
addEventHandler("onClientResourceStop", root, tas.stop)

-- // Event Commands
function tas.commands(cmd, ...) 

	local args = {...}
	
	local vehicle = tas.cveh(localPlayer)
	
	if cmd == tas.registered_commands.tas then
		if #args == 0 then
			tas.prompt("")
			tas.prompt("Recording Tool $$v1.4.3 ##by #FFAAFFchris1384##!", 255, 100, 100)
			tas.prompt("For updates and documentation, please see the $$GitHub ##link below:", 255, 100, 100)
			tas.prompt("https://github.com/chris1384/mta-tas-dm $$(copied to clipboard)", 255, 100, 255)
			tas.prompt("For #64FF64futher help ##or #FF3232bug reports##, please send me a message on #5865F2Discord##!", 255, 100, 100)
			tas.prompt("Thank $$you ##for using my tool, and to $$everyone ##who contributed to it! $$♥", 255, 100, 100)
			setClipboard("https://github.com/chris1384/mta-tas-dm")
		elseif #args >= 1 then
			for k,v in pairs(tas.registered_commands) do
				if v == args[1] then
					local command_args = args
					command_args[1] = nil
					executeCommandHandler(tas.registered_commands[k], unpack(command_args))
					return
				end
			end
		end
		
		return true
	-- // Record
	elseif cmd == tas.registered_commands.record then
		
		if not vehicle then tas.prompt("Recording failed, get a $$vehicle ##first!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("Recording failed, stop $$playbacking ##first!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Recording failed, please wait for the resume trigger!", 255, 100, 100) return end
		if tas.timers.saving_timer then tas.prompt("Recording failed, please wait for the file to be $$saved##!", 255, 100, 100) return end
		if tas.var.rewinding or tas.timers.rewind_load then tas.prompt("Recording failed, please wait for the rewinding trigger!", 255, 100, 100) return end
		
		if tas.settings.useWarnings then
			if not tas.var.recording and not tas.timers.warnRecord then
				tas.timers.warnRecord = setTimer(function() tas.timers.warnRecord = nil end, 5000, 1)
				if #tas.data > 0 then
					tas.prompt("Are you sure you want to start a $$new ##recording? Use $$/record ##again to proceed.", 255, 100, 100)
					return 
				end
			end
		end
		
		if isTimer(tas.timers.warnRecord) then
			killTimer(tas.timers.warnRecord)
		end
		tas.timers.warnRecord = nil
		
		if tas.var.recording then
		
			if tas.timers.load_warp then tas.prompt("Stopping record failed, please wait a bit!", 255, 100, 100) return end
			
			removeEventHandler("onClientPreRender", root, tas.render_record)
			tas.var.recording = false
			
			tas.var.rewinding = false
			if tas.timers.rewind_load then
				killTimer(tas.timers.rewind_load)
				tas.timers.rewind_load = nil
			end
			
			tas.prompt("Recording stopped! ($$#"..tostring(#tas.data).." ##frames)", 100, 255, 100)
		else
			tas.data = {}
			
			if not tas.settings.keepWarpData then
				tas.warps = {}
			end
			
			tas.var.recording = true
			tas.var.record_tick = getTickCount()
			tas.var.fps = getFPSLimit()
			addEventHandler("onClientPreRender", root, tas.render_record, true, "high+10")
			
			tas.prompt("Recording frames..", 100, 255, 100)
		end
		
	-- // Playback
	elseif cmd == tas.registered_commands.playback then
	
		if not vehicle then tas.prompt("Playbacking failed, get a $$vehicle ##first!", 255, 100, 100) return end
		if #tas.data < 1 then tas.prompt("Playbacking failed, no $$recorded data ##found!", 255, 100, 100) return end
		if tas.var.recording then tas.prompt("Playbacking failed, stop $$recording ##first!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Playbacking failed, please wait for the resume trigger!", 255, 100, 100) return end
		if tas.var.rewinding or tas.timers.rewind_load then tas.prompt("Playbacking failed, please wait for the rewinding trigger!", 255, 100, 100) return end
		
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
			
			if tas.settings.useOnlyBinds then
				setElementPosition(vehicle, unpack(tas.data[tas.var.play_frame].p))
				setElementRotation(vehicle, unpack(tas.data[tas.var.play_frame].r))
				setElementVelocity(vehicle, unpack(tas.data[tas.var.play_frame].v))
				setElementAngularVelocity(vehicle, unpack(tas.data[tas.var.play_frame].rv))
			end
			
			if tas.settings.useNitroStates then
				tas.nos(vehicle, tas.data[tas.var.play_frame].n)
			end
			
			if tas.settings.useHealthStates then
				setElementHealth(vehicle, tas.data[tas.var.play_frame].h)
			end
			
			tas.var.delta = tas.var.record_tick
			
			tas.prompt("Playbacking started!", 100, 100, 255)
		end
	
	-- // Save Warp
	elseif cmd == tas.registered_commands.save_warp then
	
		if not vehicle then tas.prompt("Saving warp failed, get a $$vehicle ##first!", 255, 100, 100) return end
		if tas.timers.load_warp then tas.prompt("Saving warp failed, please wait for the $$warp ##to $$load##!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Saving warp failed, please wait for the resume trigger!", 255, 100, 100) return end
		if tas.timers.saving_timer then tas.prompt("Saving warp failed, please wait for the file to be $$saved##!", 255, 100, 100) return end
		if tas.var.rewinding or tas.timers.rewind_load then tas.prompt("Saving warp failed, please wait for the rewinding trigger!", 255, 100, 100) return end
		
		local _, p, r, v, rv, health, model, nos, keys = tas.record_state(vehicle)
		local tick = nil
		local frame = #tas.data
		
		if not tas.var.recording then
			tick, frame = nil, nil
		else
			tick = tas.data[#tas.data].tick
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
		if tas.var.rewinding or tas.timers.rewind_load then tas.prompt("Loading warp failed, please wait for the rewinding trigger!", 255, 100, 100) return end
		
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
				tas.prompt("Recording stopped for safety, use $$/"..tas.registered_commands.resume.." ##to properly continue your run!", 255, 100, 100) 
				tas.prompt("Save: "..tostring(w_data.tick).." | Last: "..tostring(tas.data[#tas.data].tick), 255, 100, 100)  
			end
		end
		
		setElementPosition(vehicle, unpack(w_data.p))
		setElementRotation(vehicle, unpack(w_data.r))
		
		setElementHealth(vehicle, (tas.settings.antiExplode == true and math_max(w_data.h, 251)) or w_data.h)
		
		setElementFrozen(vehicle, true)
		
		if tas.settings.useVehicleChange then
			if getElementModel(vehicle) ~= w_data.m then
				setElementModel(vehicle, w_data.m)
				triggerServerEvent("tas:syncClient", vehicle, "vehiclechange", w_data.m)
			end
		end
		
		if tas.timers.load_warp then 
			killTimer(tas.timers.load_warp) 
			tas.timers.load_warp = nil 
		end
		
		local load_startTick = getTickCount()
		local fps_to_ms = math_ceil(1000 / tas.var.fps)
		
		tas.timers.load_warp = 	setTimer(function()
		
			if tas.var.recording and getTickCount() - load_startTick > fps_to_ms + tas.settings.warpDelay then
				setTimer(executeCommandHandler, 50, 1, tas.registered_commands.load_warp) -- ez hax, can get softlocked
			end
		
			setElementFrozen(vehicle, false)
			
			setElementPosition(vehicle, unpack(w_data.p))
			setElementRotation(vehicle, unpack(w_data.r))
			setElementVelocity(vehicle, unpack(w_data.v))
			setElementAngularVelocity(vehicle, unpack(w_data.rv))
			
			setElementHealth(vehicle, w_data.h)
		
			tas.nos(vehicle, w_data.n)
			
			if tas.var.recording then
				tas.data[#tas.data].tick = tas.data[#tas.data-1].tick + fps_to_ms * tas.var.gamespeed
				tas.var.record_tick = getTickCount() - w_data.tick
				addEventHandler("onClientPreRender", root, tas.render_record, true, "high+10")
			end
			
			tas.timers.load_warp = nil
			
		end, tas.settings.warpDelay, 1)
								
		tas.prompt("Warp $$#"..tostring(warp_number).." ##loaded!", 255, 180, 60)
		
	-- // Delete Warp
	elseif cmd == tas.registered_commands.delete_warp then
	
		if tas.timers.saving_timer then tas.prompt("Deleting warp failed, please wait for the file to be $$saved##!", 255, 100, 100) return end
		
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
		if tas.timers.saving_timer then tas.prompt("Resuming failed, please wait for the file to be $$saved##!", 255, 100, 100) return end
		if tas.var.rewinding or tas.timers.rewind_load then tas.prompt("Resuming failed, please wait for the rewinding trigger!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("Resuming failed, stop $$playbacking ##first!", 255, 100, 100) return end
		if tas.var.fps ~= nil then
			if getFPSLimit() ~= tas.var.fps then 
				tas.prompt("Resuming failed, recorded FPS was $$"..tostring(tas.var.fps).."##!", 255, 100, 100) 
				return 
			end
		else
			tas.var.fps = getFPSLimit()
		end
	
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
		
		setElementHealth(vehicle, (tas.settings.antiExplode == true and math_max(resume_data.h, 251)) or resume_data.h)
		
		setElementFrozen(vehicle, true)
		
		if tas.settings.useVehicleChange then
			if getElementModel(vehicle) ~= resume_data.m then
				setElementModel(vehicle, resume_data.m)
				triggerServerEvent("tas:syncClient", vehicle, "vehiclechange", resume_data.m)
			end
		end
		
		tas.var.rewinding = false
		if tas.timers.rewind_load then
			killTimer(tas.timers.rewind_load)
			tas.timers.rewind_load = nil
		end
		
		tas.timers.resume_load = setTimer(function()
		
			setElementFrozen(vehicle, false)
			
			setElementVelocity(vehicle, unpack(resume_data.v))
			setElementAngularVelocity(vehicle, unpack(resume_data.rv))
			
			setElementHealth(vehicle, resume_data.h)
			
			tas.nos(vehicle, resume_data.n)
			
			addEventHandler("onClientPreRender", root, tas.render_record, true, "high+10")
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
		if tas.var.rewinding or tas.timers.rewind_load then tas.prompt("Seeking failed, please wait for the rewinding trigger!", 255, 100, 100) return end
		
		local seek_number = 1
		if args[1] ~= nil then
			seek_number = tonumber(args[1])
			if not seek_number or not tas.data[seek_number] or seek_number < 1 or seek_number > #tas.data - 1 then
				tas.prompt("Seeking failed, $$non-existent ##record frame!", 255, 100, 100) 
				return
			end
		end
		
		tas.var.play_frame = seek_number
		tas.var.tick_1 = tas.data[tas.var.play_frame].tick
		tas.var.tick_2 = tas.data[tas.var.play_frame+1].tick
		tas.var.record_tick = getTickCount() - (tas.data[seek_number].tick / tas.settings.playbackSpeed)
		
		tas.var.delta = getTickCount() -- fml
		
		if tas.settings.useOnlyBinds then
			setElementPosition(vehicle, unpack(tas.data[tas.var.play_frame].p))
			setElementRotation(vehicle, unpack(tas.data[tas.var.play_frame].r))
			setElementVelocity(vehicle, unpack(tas.data[tas.var.play_frame].v))
			setElementAngularVelocity(vehicle, unpack(tas.data[tas.var.play_frame].rv))
		end
		
		if tas.settings.useNitroStates then
			tas.nos(vehicle, tas.data[tas.var.play_frame].n)
		end
		
		if tas.settings.useHealthStates then
			setElementHealth(vehicle, tas.data[tas.var.play_frame].h)
		end
		
		if getElementModel(vehicle) ~= tas.data[tas.var.play_frame].m then
			setElementModel(vehicle, tas.data[tas.var.play_frame].m)
			triggerServerEvent("tas:syncClient", vehicle, "vehiclechange", tas.data[tas.var.play_frame].m)
		end

		if not tas.var.playbacking then
			tas.var.playbacking = true
			addEventHandler((tas.settings.playbackPreRender == true and "onClientPreRender" or "onClientRender"), root, tas.render_playback)
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
		
		if tas.settings.useWarnings then
			if fileExists(fileTarget) and not tas.timers.warnSave then
				tas.timers.warnSave = setTimer(function() tas.timers.warnSave = nil end, 5000, 1)
				tas.prompt("Existing file $$'"..args[1]..".tas' ##found! Use $$/"..tas.registered_commands.save_record.." "..args[1].." ##again to overwrite the file.", 255, 100, 100)
				return
			end
		end
		
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
				
				fileWrite(save_file, string_format("%s|%s,%s,%s|%s,%s,%s|%s,%s,%s|%s,%s,%s|%d|%d|%s|%s", tas.float(run.tick), tas.float(run.p[1]), tas.float(run.p[2]), tas.float(run.p[3]), tas.float(run.r[1]), tas.float(run.r[2]), tas.float(run.r[3]), tas.float(run.v[1]), tas.float(run.v[2]), tas.float(run.v[3]), tas.float(run.rv[1]), tas.float(run.rv[2]), tas.float(run.rv[3]), math_max(1, run.h), run.m, nos, keys).."\n")
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
						fileWrite(save_file, string_format("%d|%s|%s,%s,%s|%s,%s,%s|%s,%s,%s|%s,%s,%s|%d|%d|%s", warp.frame, tas.float(warp.tick), tas.float(warp.p[1]), tas.float(warp.p[2]), tas.float(warp.p[3]), tas.float(warp.r[1]), tas.float(warp.r[2]), tas.float(warp.r[3]), tas.float(warp.v[1]), tas.float(warp.v[2]), tas.float(warp.v[3]), tas.float(warp.rv[1]), tas.float(warp.rv[2]), tas.float(warp.rv[3]), math_max(1, warp.h), warp.m, nos).."\n")
					end
					
				end
				fileWrite(save_file, "-warps")
			end
			-- //
			
			fileClose(save_file)
			
			tas.timers.warnSave = nil
			
			tas.prompt("Your run has been saved ".. (tas.settings.usePrivateFolder == true and "$$privately ##" or "").."to $$'saves/"..args[1]..".tas'##!", 255, 255, 100)
		end
	
	-- // Load Recording
	elseif cmd == tas.registered_commands.load_record then
	
		if tas.var.recording then tas.prompt("Loading record failed, stop $$recording ##first!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("Loading record failed, stop $$playbacking ##first!", 255, 100, 100) return end
		if tas.timers.load_warp then tas.prompt("Loading record failed, wait for the $$warp ##to $$load##!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Loading record failed, wait for the $$resume ##process to finish!", 255, 100, 100) return end
		if tas.timers.saving_timer then tas.prompt("Loading record failed, please wait for the file to be $$saved##!", 255, 100, 100) return end
		if tas.var.rewinding or tas.timers.rewind_load then tas.prompt("Loading record failed, please wait for the rewinding trigger!", 255, 100, 100) return end
		
		local isPrivated = (tas.settings.usePrivateFolder == true and "@") or ""
	
		if args[1] == nil then 
			tas.prompt("Loading record failed, please specify the $$name ##of your file!", 255, 100, 100) 
			tas.prompt("Example: $$/"..tas.registered_commands.load_record.." od3", 255, 100, 100) 
			return 
		end
		
		local fileTarget = isPrivated .."saves/"..args[1]..".tas" -- cool fix, unexpected mistake
		
		local file_additional = {}
		local load_file = (fileExists(fileTarget) == true and fileOpen(fileTarget)) or false
		
		if load_file then
		
			local file_size = fileGetSize(load_file)
			local file_data = fileRead(load_file, file_size)
			
			if type(file_data) == "string" and file_data:len() > 0 then
				
				-- // Recording part
				
				tas.data = {}
				
				local run_lines = tas.ambatublou(file_data, "+run", "-run")
				
				if run_lines then
					local run_data = split(run_lines, "\n")
					
					if run_data and type(run_data) == "table" and #run_data > 1 then
						
						for i=1, #run_data do
						
							local att = split(run_data[i], "|")
							
							if #att > 4 then
							
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
								
								table.insert(tas.data, {tick = tonumber(att[1]), p = p, r = r, v = v, rv = rv, h = math_max(1, tonumber(att[6])), m = tonumber(att[7]), n = n, k = keys})
							
							else
							
								if tas.settings.abortOnInvalidity then
								
									tas.prompt("Loading record failed, recurring $$error ##during reading file! (invalid run data)", 255, 100, 100)
									fileClose(load_file)
									tas.data = {}
									tas.warps = {}
									
									return
								else
									tas.prompt("Loading record warning, invalid run line $$#"..tostring(i).." ##skipped.", 255, 100, 100)
								end
							
							end
						end
					end
				end
				-- //
				
				-- // Warps part
				
				tas.warps = {}
				
				local warp_lines = tas.ambatublou(file_data, "+warps", "-warps")
				
				if warp_lines then
					local warp_data = split(warp_lines, "\n")
					if warp_data and type(warp_data) == "table" and #warp_data > 1 then
						
						for i=1, #warp_data do
						
							local att = split(warp_data[i], "|")
							
							if #att > 5 then
							
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
								
								table.insert(tas.warps, {frame = tonumber(att[1]), tick = tonumber(att[2]), p = p, r = r, v = v, rv = rv, h = math_max(1, tonumber(att[7])), m = tonumber(att[8]), n = n})
								
							else
							
								if tas.settings.abortOnInvalidity then
								
									tas.prompt("Loading record failed, recurring $$error ##during reading file! (invalid warp data)", 255, 100, 100)
									fileClose(load_file)
									tas.data = {}
									tas.warps = {}
									return
								
								else
									tas.prompt("Loading record warning, invalid run line $$#"..tostring(i).." ##skipped.", 255, 100, 100)
								end
							end
						end
						
					end
				end
				
				-- // Info Part
				file_additional.author = string_gsub(gettok(gettok(file_data, 2, "\n"), 1, "|"), "# Author: ", "")
				if not file_additional.author then file_additional.author = "Unknown" end
				
				if #tas.data > 100 then
					local stacked, elements = 0, 0
					for i=2, 100 do
						stacked = stacked + (tas.data[i].tick - tas.data[i-1].tick)
						elements = elements + 1
					end
					local fps_calculated = 1000/(stacked/elements)
					tas.var.fps = (fps_calculated>=0 and math.floor(fps_calculated+0.5)) or math.ceil(fps_calculated-0.5)
				end
			else
			
				tas.prompt("Loading record failed, recurring $$error ##during reading file! (empty or missing permissions)", 255, 100, 100)
				fileClose(load_file)
				tas.data = {}
				tas.warps = {}
				
				return
			end
			-- //
			
			fileClose(load_file)
			
			tas.timers.warnSave = nil
			
			local hunter_found = nil
			for i=#tas.data, 1, -1 do
				if hunter_found == nil then
					if tas.data[i].m == 425 then hunter_found = true end
				elseif hunter_found == true then
					if tas.data[i].m ~= 425 then hunter_found = i break end
				end
			end
			
			if type(hunter_found) ~= "number" then hunter_found = #tas.data end
			
			file_additional.time = string.format("%02d:%02d:%02d", math.floor(tas.data[hunter_found].tick/1000/60), tas.data[hunter_found].tick/1000%60, (tas.data[#tas.data].tick/1000%1)*100)
			if not file_additional.time then file_additional.time = "N/A" end
			
			tas.prompt("File '$$"..args[1]..".tas##' has been loaded! ($$"..tostring(tas.var.fps).." ##FPS / $$"..tostring(#tas.data).." ##frames / $$"..tostring(#tas.warps).." ##warps)", 255, 255, 100)
			tas.prompt("Author: $$".. file_additional.author.."##/ Time: $$".. file_additional.time, 255, 255, 100)
			
		else
		
			tas.prompt("Loading record failed, file does not $$exist##!", 255, 100, 100) 
			return
			
		end
	
	-- // Auto-TAS
	elseif cmd == tas.registered_commands.autotas then
	
		tas.settings.trigger_mapStart = not tas.settings.trigger_mapStart
		
		local status = (tas.settings.trigger_mapStart == true) and "ENABLED" or "DISABLED"
		
		updateUserConfig()
		
		tas.prompt("Auto-TAS is now: $$".. tostring(status), 255, 100, 255)
	
	-- // Clear all data
	elseif cmd == tas.registered_commands.clear_all then
	
		if tas.var.recording then tas.prompt("Clearing all data failed, stop $$recording ##first!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("Clearing all data failed, stop $$playbacking ##first!", 255, 100, 100) return end
		if tas.timers.load_warp then tas.prompt("Clearing all data failed, wait for the $$warp ##to $$load##!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Clearing all data failed, wait for the $$resume ##process to finish!", 255, 100, 100) return end
		if tas.timers.saving_timer then tas.prompt("Clearing all data failed, please wait for the file to be $$saved##!", 255, 100, 100) return end
		if tas.var.rewinding or tas.timers.rewind_load then tas.prompt("Clearing all data failed, please wait for the rewinding trigger!", 255, 100, 100) return end
		if #tas.data == 0 and #tas.warps == 0 then tas.prompt("Nothing to clear.", 255, 100, 100) return end
		
		if tas.settings.useWarnings then
			if #tas.data > 0 and not tas.timers.warnClear then
				tas.timers.warnClear = setTimer(function() tas.timers.warnClear = nil end, 5000, 1)
				tas.prompt("Are you sure you want to $$clear ##everything? Use $$/"..tas.registered_commands.clear_all.." ##again to proceed.", 255, 100, 100)
				return 
			end
		end
		
		tas.timers.warnClear = nil
		tas.timers.warnSave = nil
		
		tas.var.rewinding = false
		if tas.timers.rewind_load then
			killTimer(tas.timers.rewind_load)
			tas.timers.rewind_load = nil
		end
		
		tas.data = {}
		tas.warps = {}
		tas.var.prompts = {}
		
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
			tas.settings.debugging.offsetX = 160
		end
		
		tas.settings.debugging.level = debug_number
		
		updateUserConfig()
		
		tas.prompt("Debugging level is now set to: $$".. tostring(debug_number), 255, 100, 255)
		
	-- // Change settings
	elseif cmd == tas.registered_commands.cvar then
	
		if tas.var.recording then tas.prompt("Setting cvar failed, stop $$recording ##first!", 255, 100, 100) return end
		if tas.var.playbacking then tas.prompt("Setting cvar failed, stop $$playbacking ##first!", 255, 100, 100) return end
		if tas.timers.load_warp then tas.prompt("Setting cvar failed, wait for the $$warp ##to $$load##!", 255, 100, 100) return end
		if tas.timers.resume_load then tas.prompt("Setting cvar failed, wait for the $$resume ##process to finish!", 255, 100, 100) return end
	
		local key = args[1]
		local value = args[2]
		
		if not key then 
			tas.prompt("Setting cvar failed, syntax is: $$/"..tas.registered_commands.cvar.." key value", 255, 100, 100) 
			tas.prompt("Key is $$cvar name ##and value is your new value. Use $$/tascvar show ##to see all cvars.", 255, 100, 100) 
			return 
		end 
		
		if key == "show" then
			tas.prompt("")
			tas.prompt("Configurable variables list:", 255, 100, 255)
			for k,v in pairs(tas.settings) do
				if type(v) ~= "table" then
					tas.prompt(tostring(k).. ": "..tostring(v).." $$("..tostring(type(v)):upper()..")", 255, 100, 255)
				end
			end
			return
			
		else
			if tas.settings[key] ~= nil then
			
				local value_type = type(tas.settings[key])
				
				if value == nil then
					tas.prompt(tostring(key).. ": "..tostring(tas.settings[key]).." $$(".. value_type:upper() ..")", 255, 100, 255)
					return
				end
				
				if value_type == "number" then
					value = tonumber(value)
				elseif value_type == "string" then
					value = tostring(value)
				elseif value_type == "boolean" then
					value = (value == "true")
				end
				
				if value ~= nil then
					local old = tas.settings[key]
					tas.settings[key] = value
					tas.prompt("Changed $$"..key.." ##value to $$"..tostring(value).." ##(old: $$"..tostring(old).."##)", 255, 100, 255) 
					
					updateUserConfig()
					
				else
					tas.prompt("Setting cvar failed, invalid key $$value##!", 255, 100, 100)
					return
				end
				
			else
				tas.prompt("Setting cvar failed, setting key does not exist!", 255, 100, 100) 
				return
			end
		end
		
	-- // Show Help
	elseif cmd == tas.registered_commands.help then
		
		local all_commands = {
			"/"..tas.registered_commands.record.." $$| ##/"..tas.registered_commands.playback.." $$- ##start $$| ##playback your record",
			"/"..tas.registered_commands.save_warp.." $$| ##/"..tas.registered_commands.load_warp.." [ID] $$| ##/"..tas.registered_commands.delete_warp.." $$- ##save $$| ##load [warp ID] $$| ##delete last warp",
			"/"..tas.registered_commands.resume.." $$| ##/"..tas.registered_commands.seek.." $$- ##resume $$| ##seek from a frame",
			tas.settings.rewindingKey:upper().." $$- ##rewind during recording $$| ##L-SHIFT $$- ##x2 $$| ##L-ALT $$- ##x0.5",
			"/"..tas.registered_commands.save_record.." $$| ##/"..tas.registered_commands.load_record.." $$- ##save $$| ##load a TAS file",
			"/"..tas.registered_commands.autotas.." $$- ##toggle automatic record/playback",
			"/"..tas.registered_commands.clear_all.." $$- ##clear all cached data",
			"/"..tas.registered_commands.debug.." [0-3] $$- ##toggle debugging",
			"/"..tas.registered_commands.cvar.." $$- ##change settings, use $$/"..tas.registered_commands.cvar.." show ##for all cvars",
			"/saverg $$| ##/loadrg $$- ##save $$| ##load a TAS file from serverside", -- assuming default command
			"/forcecancel $$- ##cancel save/load TAS from serverside", -- assuming default command
		}

		local page_count = math_ceil(#all_commands/5)
		local page_target = tas.clamp(1, tonumber(args[1]) or 1, page_count)
		local page_rows = 5*(page_target-1)
		
		tas.prompt("")
		tas.prompt("Commands List $$(page "..tostring(page_target).."/"..tostring(page_count)..")##:", 255, 100, 100)
		for i=1+page_rows,5+page_rows do
			tas.prompt(all_commands[i], 255, 100, 100)
		end
		
		all_commands = nil
		
	end
end


-- // Binds
function tas.binds(key, state)
	
	-- // RECORD
	if key == tas.settings.editorRecordKey then
	
		if not tas.settings.enableEditorMode or tas.settings.editorRecordMode == "none" then return end
		if not getResourceFromName("editor_main") then return end
	
		if not state then
		
			if isMTAWindowActive() or isCursorShowing() then return end
			
			if tas.settings.editorRecordMode == "new" then
				executeCommandHandler(tas.registered_commands.record)
				
			elseif tas.settings.editorRecordMode == "resume" then
				executeCommandHandler(((tas.var.recording == true or #tas.data == 0) and tas.registered_commands.record) or tas.registered_commands.resume)
			end
			
		end
		
	-- // DUMMY
	elseif key == tas.settings.editorDummyKey then
	
		if not tas.settings.enableEditorMode then return end
		if not tas.settings.editorEnableDummy then return end
		if not getResourceFromName("editor_main") then return end
	
		if state then
		
			if isMTAWindowActive() or exports["editor_main"]:getSelectedElement() then return end
			
			if tas.var.editor_select then
			
				exports["editor_main"]:setWorldClickEnabled(false) -- thanks @Sorata
				
				local data = tas.var.editor_select
				
				if tas.var.editor_dummy_client and isElement(tas.var.editor_dummy_client) then -- if for some reason our ghost dummy still exist (how tf would it be)
					destroyElement(tas.var.editor_dummy_client)
					tas.var.editor_dummy_client = nil
				end
				
				tas.var.editor_dummy_client = createVehicle(data.m, 0, 0, 0)
				
				if tas.var.editor_dummy_client then
				
					setElementFrozen(tas.var.editor_dummy_client, true)
					setElementCollisionsEnabled(tas.var.editor_dummy_client, false)
					setElementDimension(tas.var.editor_dummy_client, exports["editor_main"]:getWorkingDimension() or 200)
					
					setTimer(function()
						if tas.var.editor_dummy_client ~= nil then
							setElementPosition(tas.var.editor_dummy_client, data.p[1], data.p[2], data.p[3])
							setElementRotation(tas.var.editor_dummy_client, data.r[1], data.r[2], data.r[3])
						end
					end, 20, 1)
					
					setVehicleColor(tas.var.editor_dummy_client, 255, 0, 0, 255, 255, 255, 255, 0, 0, 255, 255, 255)
					setElementAlpha(tas.var.editor_dummy_client, 180)
					
				end
				
			end
			
		else
			if tas.var.editor_dummy_client and isElement(tas.var.editor_dummy_client) then -- this can get bugged too under rare circumstances
			
				destroyElement(tas.var.editor_dummy_client)
				local data = tas.var.editor_select
				triggerServerEvent("tas:edfCreate", localPlayer)
				triggerServerEvent("doCreateElement", localPlayer, "vehicle", "editor_main", {position = data.p, rotation = data.r, model = data.m}, false, false)
			end
			
			-- // at least make sure our variables are correct for the next spawning
			
			tas.var.editor_dummy_client = nil
			tas.var.editor_select = false
			
			exports["editor_main"]:setWorldClickEnabled(true)
		end
		
	end
end

-- // Recording
function tas.render_record(deltaTime)

	local vehicle = tas.cveh(localPlayer)
	
	if vehicle then

		local model = getElementModel(vehicle)
		
		if tas.settings.hunterFinish then
			if model == 425 then
			
				removeEventHandler("onClientPreRender", root, tas.render_record)
				tas.var.recording = false
				
				for i=1, 3 do
					tas.data[#tas.data] = nil
				end
		
				tas.prompt("Hunter has been reached! Stopped recording. ($$#"..tostring(#tas.data).." ##frames)", 100, 255, 100)
				
				return
			end
		end
		
		local total_frames = #tas.data
		
		-- // I don't like this part, at all
		if getKeyState(tas.settings.rewindingKey) and not (isMTAWindowActive() or isCursorShowing()) then
		
			if not (tas.timers.load_warp or tas.timers.resume_load) then
			
				tas.var.rewinding = true
				
				-- // Offended by trashy logic? Please seek some drama elsewhere. (idk what i did but it works)
				local frame_advance = 0
				
				if getKeyState("lshift") then
					frame_advance = 2
					
				elseif getKeyState("lalt") then
				
					if tas.var.rewind_cache == nil or tas.var.rewind_cache == 0 then
						tas.var.rewind_cache = total_frames
					end
				
					if tas.var.rewind_cache % 1 == 0 then
						frame_advance = 1
					end
					tas.var.rewind_cache = tas.var.rewind_cache - 0.25
					
				else
					tas.var.rewind_cache = 0
					frame_advance = 1
				end
				
				local frame_data = tas.data[total_frames-frame_advance]
				
				setElementPosition(vehicle, unpack(frame_data.p))
				setElementRotation(vehicle, unpack(frame_data.r))
				setElementVelocity(vehicle, unpack(frame_data.v))
				setElementAngularVelocity(vehicle, unpack(frame_data.rv))
				
				if tas.settings.useVehicleChange then
					if model ~= frame_data.m then
						setElementModel(vehicle, frame_data.m)
						triggerServerEvent("tas:syncClient", vehicle, "vehiclechange", frame_data.m)
					end
				end
				
				if tas.settings.useHealthStates then
					setElementHealth(vehicle, (tas.settings.antiExplode == true and math_max(frame_data.h, 251)) or frame_data.h)
				end
				
				if tas.settings.useNitroStates then
					tas.nos(vehicle, frame_data.n)
				end
				
				if tas.warps[#tas.warps] ~= nil then
					if tas.warps[#tas.warps].tick == nil or tas.warps[#tas.warps].tick > frame_data.tick then
						tas.warps[#tas.warps] = nil
					end
				end
				
				if total_frames > 5 then
					for i=total_frames-frame_advance+1, total_frames do
						tas.data[i] = nil
					end
				end
				return
				
			end
			
		else
		
			if tas.var.rewinding then
			
				tas.var.rewinding = false
				
				tas.var.rewind_cache = 0
				
				if tas.timers.rewind_load then
					if isTimer(tas.timers.rewind_load) then
						killTimer(tas.timers.rewind_load)
					end
					tas.timers.rewind_load = nil
				end
				
				if tas.settings.rewindingDelay > 50 then
					tas.timers.rewind_load = setTimer(function() tas.timers.rewind_load = nil end, tas.settings.rewindingDelay, 1)
				end
				
				if tas.settings.rewindingCameraReset then
					setCameraTarget(localPlayer)
				end
				
			end
			
			if tas.timers.rewind_load then
			
				local frame_data = tas.data[total_frames]
				tas.var.record_tick = getTickCount() - frame_data.tick
				
				setElementPosition(vehicle, unpack(frame_data.p))
				setElementRotation(vehicle, unpack(frame_data.r))
				setElementVelocity(vehicle, unpack(frame_data.v))
				setElementAngularVelocity(vehicle, unpack(frame_data.rv))
				
				if tas.settings.useVehicleChange then
					if getElementModel(vehicle) ~= frame_data.m then
						setElementModel(vehicle, frame_data.m)
						triggerServerEvent("tas:syncClient", vehicle, "vehiclechange", frame_data.m)
					end
				end
				setElementHealth(vehicle, (tas.settings.antiExplode == true and math_max(frame_data.h, 251)) or frame_data.h)
				
				if tas.settings.useNitroStates then
					tas.nos(vehicle, frame_data.n)
				end
				
				return
			end
			
		end
	
		local tick, p, r, v, rv, health, model, nos, keys, ground, analog = tas.record_state(vehicle)
		local marked = nil
		
		local gamespeed = (tas.settings.useGameSpeed == true and getGameSpeed()) or 1
		if tas.var.gamespeed ~= gamespeed then
			tas.var.gamespeed_event = true
			tas.var.gamespeed = gamespeed
		end
		
		local previous_frame = tas.data[total_frames]
		if previous_frame then
		
			local fps_to_ms = 1000 / tas.var.fps
			local fps_magnitude = tas.var.fps / 50
			
			local x, y, z = unpack(p)
			local x2, y2, z2 = unpack(previous_frame.p)
			local segment_distance = tas.dist3D(x, y, z, x2, y2, z2)
			
			local vx, vy, vz = v[1]/fps_magnitude, v[2]/fps_magnitude, v[3]/fps_magnitude
			local kmh = tas.dist3D(0, 0, 0, vx, vy, vz)
		
			if tas.settings.useGameSpeed then
				if tas.var.gamespeed_event then
					tas.data[total_frames].marked = {255, 255, 255}
					if gamespeed ~= 1 then
						tas.data[total_frames].tick = tas.data[total_frames].tick - fps_to_ms + (fps_to_ms * gamespeed)
					else
						tas.data[total_frames].tick = tas.data[total_frames].tick + deltaTime
					end
					tas.var.gamespeed_event = false
				end
			end
			
			marked = (gamespeed ~= 1 and {0, 0, 255}) or nil
			
			tick = previous_frame.tick + deltaTime * gamespeed
			
			if deltaTime >= fps_to_ms * 2 then
				if kmh > 0 and segment_distance < 100 then
					tas.data[total_frames].tick = tas.data[total_frames].tick + ((segment_distance / kmh) * fps_to_ms)
					tas.data[total_frames].marked = {0, 255, 0}
					tick = previous_frame.tick + fps_to_ms * gamespeed
				end
			end
		end
		
		table_insert(tas.data, 	{
			tick = tick,
			p = p,
			r = r,
			v = v,
			rv = rv,
			h = math_max(1, health),
			m = model,
			n = nos,
			k = keys,
			g = ground,
			a = analog,
			marked = marked,
		})
		
	else
	
		removeEventHandler("onClientPreRender", root, tas.render_record)
		tas.var.recording = false

		tas.var.rewinding = false
		if tas.timers.rewind_load then
			killTimer(tas.timers.rewind_load)
			tas.timers.rewind_load = nil
		end
		
		tas.prompt("Recording stopped due to an error! ($$#"..tostring(#tas.data).." ##frames)", 255, 100, 100)
					
	end
end

-- // Recording vehicle state
function tas.record_state(vehicle)

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
		for key, control in pairs(tas.registered_keys) do
			if getKeyState(key) then
				if not keys then keys = {} end
				table_insert(keys, control.c_bind)
			end
		end
		
		local analog = nil
		if tas.settings.enableAnalog and tas.settings.useAnalogWrapper then
			if not analog then analog = {left = 0, right = 0} end
			analog.left = math_abs(math_min(0, tas.var.analog_direction))
			analog.right = math_abs(math_max(0, tas.var.analog_direction))
		else
			local anl = getPedAnalogControlState(localPlayer, "vehicle_left", true)
			local anr = getPedAnalogControlState(localPlayer, "vehicle_right", true)
			if anl ~= 0 and anl ~= 1 then
				if not analog then analog = {left = 0, right = 0} end
				analog.left = anl
			end
			if anr ~= 0 and anl ~= 1 then
				if not analog then analog = {left = 0, right = 0} end
				analog.right = anr
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
		
		return real_time, p, r, v, rv, health, model, nos, keys, ground, analog
					
	end
end

-- // Analog Control Wrap

function tas.analogControl()

	if tas.settings.enableAnalog and tas.settings.useAnalogWrapper and not tas.var.playbacking then
	
		if isMTAWindowActive() or isCursorShowing() then 
			setAnalogControlState("vehicle_right", 0, false)
			setAnalogControlState("vehicle_left", 0, false)
			tas.var.analog_direction = 0
			return
		end -- do not steer when cursor or any mta window is showing
		
		local lefts = getBoundKeys("vehicle_left")
		local rights = getBoundKeys("vehicle_right")
		local left_press = false
		local right_press = false
		for k,v in pairs(lefts) do
			if getKeyState(k) then
				left_press = true
				break
			end
		end
		for k,v in pairs(rights) do
			if getKeyState(k) then
				right_press = true
				break
			end
		end
		
		if left_press and right_press then
			tas.var.analog_direction = 0
		elseif left_press then
			if tas.var.analog_direction > 0 then tas.var.analog_direction = 0 end
			tas.var.analog_direction = math_max(-1, tas.var.analog_direction - tas.settings.analogSensitivity)
		elseif right_press then
			if tas.var.analog_direction < 0 then tas.var.analog_direction = 0 end
			tas.var.analog_direction = math_min(1, tas.var.analog_direction + tas.settings.analogSensitivity)
		elseif tas.var.analog_direction ~= 0 and not (right_press or left_press) then
			if tas.var.analog_direction == 0 then
			elseif tas.var.analog_direction > 0 then
				tas.var.analog_direction = math_max(0, tas.var.analog_direction - tas.settings.analogSensitivity * 1.333)
			else
				tas.var.analog_direction = math_min(0, tas.var.analog_direction + tas.settings.analogSensitivity * 1.333)
			end
		end
		
		if tas.var.analog_direction == 0 then
			setAnalogControlState("vehicle_right", 0, false)
			setAnalogControlState("vehicle_left", 0, false)
		elseif tas.var.analog_direction > 0 then
			setAnalogControlState("vehicle_right", tas.var.analog_direction, true)
		else
			setAnalogControlState("vehicle_left", -tas.var.analog_direction, true)
		end
		
	end
	
end
addEventHandler("onClientPreRender", root, tas.analogControl)

-- // Playbacking
function tas.render_playback()

	local vehicle = tas.cveh(localPlayer)
	
	if vehicle and not isPedDead(localPlayer) then
		
		local inbetweening = 0

		if tas.settings.playbackInterpolation then
		
			local current_tick = getTickCount()
			local time_difference = current_tick - tas.var.delta
			
			if tas.settings.adaptiveInterpolation and time_difference >= tas.settings.adaptiveThreshold then
				tas.var.record_tick = tas.var.record_tick + time_difference -- huh that was easy
			end
			
			local real_time = (current_tick - tas.var.record_tick) * tas.settings.playbackSpeed
		
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
			
			tas.var.delta = current_tick
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
		
		if not tas.settings.useOnlyBinds then
		
			local x = tas.lerp(frame_data.p[1], frame_data_next.p[1], inbetweening)
			local y = tas.lerp(frame_data.p[2], frame_data_next.p[2], inbetweening)
			local z = tas.lerp(frame_data.p[3], frame_data_next.p[3], inbetweening)
			setElementPosition(vehicle, x, y, z)
			
			local rx = tas.lerp_angle(frame_data.r[1], frame_data_next.r[1], inbetweening)
			local ry = tas.lerp_angle(frame_data.r[2], frame_data_next.r[2], inbetweening)
			local rz = tas.lerp_angle(frame_data.r[3], frame_data_next.r[3], inbetweening)
			setElementRotation(vehicle, rx, ry, rz)
			
			-- // added lerp to these 2 aswell (prob overkill)
			local vx = tas.lerp(frame_data.v[1], frame_data_next.v[1], inbetweening)
			local vy = tas.lerp(frame_data.v[2], frame_data_next.v[2], inbetweening)
			local vz = tas.lerp(frame_data.v[3], frame_data_next.v[3], inbetweening)
			setElementVelocity(vehicle, vx, vy, vz)
			
			local rvx = tas.lerp(frame_data.rv[1], frame_data_next.rv[1], inbetweening)
			local rvy = tas.lerp(frame_data.rv[2], frame_data_next.rv[2], inbetweening)
			local rvz = tas.lerp(frame_data.rv[3], frame_data_next.rv[3], inbetweening)
			setElementAngularVelocity(vehicle, rvx, rvy, rvz)
			
			if tas.settings.useVehicleChange then
			
				local model = getElementModel(vehicle)
				
				if tas.settings.hunterFinish then
					if model == 425 or frame_data.m == 425 then
						removeEventHandler((tas.settings.playbackPreRender == true and "onClientPreRender" or "onClientRender"), root, tas.render_playback)
						tas.var.playbacking = false
						tas.resetBinds()
						
						tas.prompt("Hunter has been reached! Stopped playbacking.", 100, 100, 255)
						return
					end
				end
				
				if model ~= frame_data_next.m then
					setElementModel(vehicle, frame_data_next.m)
					triggerServerEvent("tas:syncClient", vehicle, "vehiclechange", frame_data_next.m)
				end
				
			end
			
			if tas.settings.useHealthStates then
				setElementHealth(vehicle, frame_data.h)
			end
			
		end
		
		tas.resetBinds()
		if frame_data.k then
			for k,v in ipairs(frame_data.k) do
				setPedControlState(localPlayer, tas.key_mappings[v], true)
			end
		end
		
		if frame_data.a then
		
			setPedControlState(localPlayer, "vehicle_left", false)
			setPedControlState(localPlayer, "vehicle_right", false)
			
			if frame_data.a.left == 0 and frame_data.a.right == 0 then
				setAnalogControlState("vehicle_left", 0, false)
				setAnalogControlState("vehicle_right", 0, false)
			elseif frame_data.a.left > 0 then
				setAnalogControlState("vehicle_left", frame_data.a.left, true)
			elseif frame_data.a.right > 0 then
				setAnalogControlState("vehicle_right", frame_data.a.right, true)
			end
			
		end
		
		if not tas.settings.useOnlyBinds then
			-- probably this cvar is not needed anymore
			if tas.settings.useNitroStates then
				tas.nos(vehicle, frame_data.n)
			end
		end
	
	else
		
		removeEventHandler((tas.settings.playbackPreRender == true and "onClientPreRender" or "onClientRender"), root, tas.render_playback)
		tas.var.playbacking = false
		tas.resetBinds()
		
		tas.prompt("Playbacking stopped due to an error! (vehicle missing)", 255, 100, 100)
			
	end
end

-- // Drawing debug
function tas.dxDebug()

	local offsetX = tas.settings.debugging.offsetX
	
	if tas.settings.debugging.level >= 1 then
		
		local left_press = getPedControlState(localPlayer, "vehicle_left")
		local right_press = getPedControlState(localPlayer, "vehicle_right")
		
		tas.dxKey("W", screenW/2-offsetX, screenH-200, 40, 40, getPedControlState(localPlayer, "accelerate") and tocolor(60, 255, 60, 255))
		tas.dxKey("S", screenW/2-offsetX, screenH-200+44, 40, 40, getPedControlState(localPlayer, "brake_reverse") and tocolor(255, 150, 50, 255))
		tas.dxKey("FIRE", screenW/2-offsetX-64, screenH-200+88, 60, 40, (getPedControlState(localPlayer, "vehicle_fire") or getPedControlState(localPlayer, "vehicle_secondary_fire")) and tocolor(60, 200, 255, 255))
		tas.dxKey("SPACE", screenW/2-offsetX, screenH-200+88, 160, 40, getPedControlState(localPlayer, "handbrake") and tocolor(255, 60, 60, 255))
		tas.dxKey("ᐱ", screenW/2-offsetX+120, screenH-200, 40, 40, getPedControlState(localPlayer, "steer_forward") and tocolor(255, 80, 255, 255))
		tas.dxKey("ᐯ", screenW/2-offsetX+120, screenH-200+44, 40, 40, getPedControlState(localPlayer, "steer_back") and tocolor(255, 80, 255, 255))
		
		if tas.settings.enableAnalog then
		
			local left_analog = math_abs(math_min(0, tas.var.analog_direction)) 
			local right_analog = math_abs(math_max(0, tas.var.analog_direction))
			
			if not tas.settings.useAnalogWrapper then
				left_analog = getAnalogControlState("vehicle_left", true)
				right_analog = getAnalogControlState("vehicle_right", true)
			end
			
			if tas.var.playbacking then
				if tas.data[tas.var.play_frame].a then
					left_analog = tas.data[tas.var.play_frame].a.left
					right_analog = tas.data[tas.var.play_frame].a.right
				else
					left_analog = (left_press and 1) or 0
					right_analog = (right_press and 1) or 0
				end
			end
			
			dxDrawImage(screenW/2-offsetX-44, screenH-200+4, 40, 80, tas.textures.triangle, 0, 0, 0, tocolor(200, 200, 200, 200))
			dxDrawImage(screenW/2-offsetX+44, screenH-200+4, 40, 80, tas.textures.triangle, 180, 0, 0, tocolor(200, 200, 200, 200))
			dxDrawImageSection(screenW/2-offsetX-44+40*(1-left_analog), screenH-200+4, 40*(left_analog), 80, 40*(1-left_analog), 0, 40*(left_analog), 80, tas.textures.triangle, 0, 0, 0, tocolor(220, 220, 50, 255))
			dxDrawImageSection(screenW/2-offsetX+44, screenH-200+4, 40*(right_analog), 80, 40*(1-right_analog), 0, 40*(right_analog), 80, tas.textures.triangle, 180, 0, 0, tocolor(220, 220, 50, 255))
			
			dxDrawText(string_format("%.1f", left_analog), screenW/2-offsetX-44, screenH-200+4, screenW/2-offsetX-44+50, screenH-200+4+80, tocolor(0, 0, 0, 255), 1.384, "default-bold", "center", "center")
			dxDrawText(string_format("%.1f", right_analog), screenW/2-offsetX+44, screenH-200+4, screenW/2-offsetX+44+30, screenH-200+4+80, tocolor(0, 0, 0, 255), 1.384, "default-bold", "center", "center")
		else
			tas.dxKey("A", screenW/2-offsetX-44, screenH-200+44, 40, 40, left_press and tocolor(220, 220, 50, 255))
			tas.dxKey("D", screenW/2-offsetX+44, screenH-200+44, 40, 40, right_press and tocolor(220, 220, 50, 255))
		end
		
	end
	
	if tas.settings.debugging.level >= 2 then
	
		local recording_extra = (tas.timers.load_warp ~= nil and "(LOADING WARP..)") or (tas.var.rewinding == true and "(REWINDING..)") or (tas.timers.rewind_load ~= nil and "(RESUMING REWINDING..)") or (tas.timers.resume_load ~= nil and "(RESUMING..)") or ""
	
		tas.dxText("Recording: ".. (tas.var.recording == true and "#64FF64ENABLED" or "#FF6464DISABLED") .. " #FFFFFF" .. recording_extra, screenW/2-offsetX+170, screenH-200+18*0, 1)
		tas.dxText("Playbacking: ".. (tas.var.playbacking == true and "#64FF64ENABLED" or "#FF6464DISABLED"), screenW/2-offsetX+170, screenH-200+18*1, 1)
		
		tas.dxText("Auto-TAS: ".. (tas.settings.trigger_mapStart == true and "#64FF64ENABLED" or "#FF6464DISABLED"), screenW/2-offsetX+170, screenH-200+18*2, 1)
		tas.dxText("Recorded FPS: #FF6464"..tostring(tas.var.fps), screenW/2-offsetX+170, screenH-200+18*4, 1)
		tas.dxText("Total Frames: #FFAAFF#".. tostring(#tas.data) .." #FFFFFF| Total Warps: #00FFFF#".. tostring(#tas.warps), screenW/2-offsetX+170, screenH-200+18*5, 1)
		
		local playback_runtime = "N/A"
		if tas.data[tas.var.play_frame] then
			playback_runtime = string_format("%02d:%02d.%03d", (tas.data[tas.var.play_frame].tick/60000)%60, (tas.data[tas.var.play_frame].tick/1000)%60, (tas.data[tas.var.play_frame].tick)%1000)
		end
		
		tas.dxText("Playback Frame: #6464FF#".. tostring(tas.var.play_frame).." #FFFFFF| Time: #6464FF".. tostring(playback_runtime), screenW/2-offsetX+170, screenH-200+18*6, 1)
		
	end
	
	tas.pathWay()
	
	if tas.settings.promptType == 2 then
		for i=1, #tas.var.prompts do
			tas.dxText(tas.var.prompts[i], 30, screenH/2-150+18*(i-1), 1)
		end
	end
	
end

function tas.pathWay()

	if tas.settings.enableEditorMode and tas.var.editor ~= "none" then

		local cursorX, cursorY
		if isCursorShowing() then
			cursorX, cursorY = getCursorPosition()
			cursorX, cursorY = cursorX * screenW, cursorY * screenH
		end
		
		local function isMouseInPosition(x, y, w, h)
			if not cursorX or not cursorY then return false end
			--dxDrawRectangle(x, y, w, h, 0xAA00FF00)
			return ((cursorX >= x and cursorX <= x + w) and (cursorY >= y and cursorY <= y + h))
		end
	
		local pX, pY, pZ = getElementPosition(localPlayer)
		
		if tas.var.editor == "cursor" then
			local foundWaypoint = false
			for i = 1, #tas.data - 1 do
				local x, y, z = unpack(tas.data[i].p)
				if not tas.settings.debugging.wholeFrameClipDistance or (tas.settings.debugging.wholeFrameClipDistance and tas.dist3D(pX, pY, pZ, x, y, z) < tas.settings.debugging.wholeFrameClipDistance) then
					local x2, y2, z2 = unpack(tas.data[i + 1].p)
					--local ground = (tas.data[i].g == true and tocolor(150, 150, 150, 150)) or tocolor(255, 0, 0, 150)
					dxDrawLine3D(x, y, z, x2, y2, z2, 0xAAFF0000, 10)
					dxDrawLine3D(x, y, z+0.15, x, y, z-0.15, 0xFFFFFFFF, 5)
					
					if not foundWaypoint then
						local sX, sY = getScreenFromWorldPosition(x, y, z, 0.05, false)
						if sX and sY then
							if cursorX and cursorY then
								local detectionWidth = 1 -- this can be helpful but annoying
								local detectionHeight = tas.var.editor_dummy_client ~= nil and 5 or 1 -- this can be helpful but annoying
								if isMouseInPosition(sX-(10*detectionWidth), sY-(20*detectionHeight), 20*detectionWidth, 40*detectionHeight) then
									foundWaypoint = tas.data[i]
									foundWaypoint.frame = i
								end
							end
						end
					end
				end
			end
			if foundWaypoint then
				tas.var.editor_select = foundWaypoint
				local text_offset = 0
				if tas.settings.editorEnableDummy then
					local dummyKeyText = "Press #FF6464'"..tas.settings.editorDummyKey:upper().."' #FFFFFFto spawn dummy"
					dxDrawText(string_gsub(dummyKeyText, "#%x%x%x%x%x%x", ""), cursorX - 10 + 1, cursorY + 30 + 1, cursorX + 30 + 1, cursorY + 40 + 1, 0xFF000000, 1, "default", "center", "top", false, false, false, true)
					dxDrawText(dummyKeyText, cursorX - 10, cursorY + 30, cursorX + 30, cursorY + 40, 0xFFFFFFFF, 1, "default", "center", "top", false, false, false, true)
					text_offset = 14
					if tas.var.editor_dummy_client then
						local data = tas.var.editor_select
						
						-- // smoother preview but can get buggy due to inconsistent cursor detection
						--local x, y, z = getElementPosition(tas.var.editor_dummy_client)
						--setElementPosition(tas.var.editor_dummy_client, tas.lerp(x, data.p[1], 0.25), tas.lerp(y, data.p[2], 0.25), tas.lerp(z, data.p[3], 0.25))
						
						setElementPosition(tas.var.editor_dummy_client, data.p[1], data.p[2], data.p[3])
						setElementRotation(tas.var.editor_dummy_client, data.r[1], data.r[2], data.r[3])
					end
				end
			else
				if not tas.var.editor_dummy_client then
					tas.var.editor_select = false
				end
			end
			
		elseif tas.var.editor == "freecam" then
			for i = 1, #tas.data - 1, tas.settings.debugging.frameSkipping do
				local x, y, z = unpack(tas.data[i].p)
				local x2, y2, z2
				local last = tas.data[i + tas.settings.debugging.frameSkipping]
				if not last then last = tas.data[#tas.data] end
				x2, y2, z2 = unpack(last.p)
				--local ground = (tas.data[i].g == true and tocolor(150, 150, 150, 150)) or tocolor(255, 0, 0, 150)
				dxDrawLine3D(x, y, z, x2, y2, z2, 0xAAFF0000, 15)
			end
		end
		return
	end

	if tas.settings.debugging.level == 2 then
	
		local frameSkipping = (tas.var.playbacking == true and 1) or tas.settings.debugging.frameSkipping
		local startFrame = (tas.var.playbacking == true and tas.var.play_frame + 2) or 0
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
	
		local tas_data_total = #tas.data
		local fps_magnitude = tas.var.fps/50
		local pX, pY, pZ = getElementPosition(localPlayer)
		
		if tas_data_total > 2 then
			for i=1, tas_data_total do
				local x, y, z = unpack(tas.data[i].p)
				
				if not tas.settings.debugging.wholeFrameClipDistance or (tas.settings.debugging.wholeFrameClipDistance and tas.dist3D(pX, pY, pZ, x, y, z) < tas.settings.debugging.wholeFrameClipDistance) then
					local vx, vy, vz = unpack(tas.data[i].v)
					vx, vy, vz = vx/fps_magnitude, vy/fps_magnitude, vz/fps_magnitude
					local rewrite = tas.data[i].marked or {255, 0, 0}
					dxDrawLine3D(x, y, z-1, x, y, z+1, tocolor(rewrite[1], rewrite[2], rewrite[3], 100), 5)
					
					local swX, swY = getScreenFromWorldPosition(x, y, z+1.1, 2)
					if swX and swY then	
						local frame_text = tostring(i).." "..tostring(tas.data[i].tick)
						if i > 1 then
							frame_text = tostring(i).." "..tostring(tas.float(tas.data[i].tick, 3)).." "..tostring(tas.float(tas.data[i].tick - tas.data[i-1].tick))
						end
						dxDrawText(frame_text, swX, swY, swX, swY, tocolor(rewrite[1], rewrite[2], rewrite[3], 255), 1, "arial", "center", "center")
					end
					
					local velocity_magnitude = tas.dist3D(0, 0, 0, vx, vy, vz)
					dxDrawLine3D(x, y, z, x+vx, y+vy, z+vz, tocolor(0, 255, 255, 100), 5)
					
					if tas.data[i+1] then
						local nx, ny, nz = unpack(tas.data[i+1].p)
						
						local frame_spacing_difference = tas.dist3D(x, y, z, nx, ny, nz)
						if frame_spacing_difference > velocity_magnitude + 0.1 then
							local mx, my, mz = tas.middle3D(x, y, z, nx, ny, nz)
							local swX, swY = getScreenFromWorldPosition(mx, my, mz+1.5, 2)
							if swX and swY then
								dxDrawText(tas.dist3D(x, y, z, nx, ny, nz), swX, swY, swX, swY, tocolor(255, 255, 0, 255), 1, "arial", "center", "center")
							end
						end
						
						local velocity_frame_difference = tas.dist3D(x+vx, y+vy, z+vz, nx, ny, nz)
						if velocity_frame_difference > 0.1 then
							dxDrawLine3D(x+vx, y+vy, z+vz, nx, ny, nz, tocolor(255, 0, 255, 100), 5)
							local swX, swY = getScreenFromWorldPosition(x+vx, y+vy, z+vz+0.5, 2)
							if swX and swY then
								dxDrawText(velocity_frame_difference, swX, swY, swX, swY, tocolor(255, 0, 255, 255), 1, "arial", "center", "center")
							end
						end
					end
				end
			end
		end
		
	end
	
	if tas.settings.debugging.warpsRenderLevel <= tas.settings.debugging.level then
		local tas_warps_total = #tas.warps
		
		if tas_warps_total >= 1 then
			for i=1, tas_warps_total do
				local x, y, z = unpack(tas.warps[i].p)
				dxDrawLine3D(x, y, z+1, x, y, z+1.7, tocolor(255, 180, 60, 255), 5)
				
				local swX, swY = getScreenFromWorldPosition(x, y, z+1.9, 2)
				if swX and swY then
					local tick = (tas.warps[i].tick ~= nil and tostring(tas.warps[i].tick) ) or ""
					dxDrawText(tostring(i).. " "..tostring(tas.warps[i].frame).." "..tick, swX, swY, swX, swY, tocolor(255, 180, 60, 255), 1, "arial", "center", "center")
				end
				
			end
		end
	end
	
end

-- // Editor Events
addEvent("onEditorSuspended")
addEventHandler("onEditorSuspended", root, function(...)
	if not getKeyState("f3") and not exports["editor_main"]:getSelectedElement() then -- LOL EZ FIX (PLEASE MAKE IT WORK)
		tas.var.editor = "none"
	end
	
	if tas.var.editor_dummy_client then
		destroyElement(tas.var.editor_dummy_client)
	end
	tas.var.editor_dummy_client = nil
	
	exports["editor_main"]:setWorldClickEnabled(true) -- forgor :skull:
end)

addEvent("onEditorResumed")
addEventHandler("onEditorResumed", root, function(...)
	setTimer(function()
		tas.var.editor = isCursorShowing() == true and "cursor" or "freecam"
	end, 150, 1)
end)

addEvent("onCursorMode")
addEventHandler("onCursorMode", root, function(...)
	tas.var.editor = "cursor"
end)

addEvent("onFreecamMode")
addEventHandler("onFreecamMode", root, function(...)
	tas.var.editor = "freecam"
	
	-- // i gotta stop forgor-ing
	if tas.var.editor_dummy_client then
		destroyElement(tas.var.editor_dummy_client)
	end
	tas.var.editor_dummy_client = nil
	
end)

-- // Cute dxKeybind
function tas.dxKey(keyName, x, y, x2, y2, color)
	dxDrawRectangle(x, y, x2, y2, color or tocolor(200, 200, 200, 200))
	dxDrawText(keyName, x, y, x+x2, y+y2, tocolor(0, 0, 0, 255), 1.384, "default-bold", "center", "center")
end

-- // Cute dxText
function tas.dxText(text, x, y, size)
	dxDrawText(text:gsub("#%x%x%x%x%x%x", ""), x+1, y+1, x+1, y+1, tocolor(0,0,0,255), size, "default", "left", "top", false, false, false, true)
	dxDrawText(text, x, y, x, y, tocolor(255,255,255,255), size, "default", "left", "top", false, false, false, true)
end

-- // Resetting ped controls
function tas.resetBinds()
	for _,v in pairs(tas.key_mappings) do
		setPedControlState(localPlayer, v, false)
	end
	setAnalogControlState("vehicle_right", 0, false)
	setAnalogControlState("vehicle_left", 0, false)
end

-- // Command messages
function tas.prompt(text, r, g, b)
	if type(text) ~= "string" then return end
	local r, g, b = r or 255, g or 100, b or 100
	local prefix = (text ~= "" and "[TAS] ") or ""
	if tas.settings.promptType == 1 then
		return outputChatBox(prefix.."#FFFFFF"..string_gsub(string_gsub(text, "%#%#", "#FFFFFF"), "%$%$", string_format("#%.2X%.2X%.2X", r, g, b)), r, g, b, true)
	elseif tas.settings.promptType == 2 then
		if not tas.var.prompts then tas.var.prompts = {} end
		table_insert(tas.var.prompts, string_format("#%.2X%.2X%.2X", r, g, b) .. prefix .."#FFFFFF"..string_gsub(string_gsub(text, "%#%#", "#FFFFFF"), "%$%$", string_format("#%.2X%.2X%.2X", r, g, b)))
		if #tas.var.prompts > 15 then
			table_remove(tas.var.prompts, 1)
		end
	elseif tas.settings.promptType == 3 then
		return iprint(prefix .. string_gsub(string_gsub(text, "%#%#", ""), "%$%$", ""))
	end
end

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

-- // Vultaic Wrapper
function tas.vultaicWrap(extra)
	if extra == nil or extra == 0 then
		tas.raceWrap("Started")
	end
end
for vultaicIndex,vultaicEvents in ipairs({"onClientTimeIsUpDisplayRequest", "onClientArenaGridCountdown", "*!TfFEv3ntS3c!*:onClientArenaGridCountdown", "*!TfFEv3ntS3c!*:onClientTimeIsUpDisplayRequest"}) do
	addEvent(vultaicEvents)
	addEventHandler(vultaicEvents, root, tas.vultaicWrap)
end

-- // Another cancellation event
function tas.minimizeEvent()
	if tas.var.recording then
		removeEventHandler("onClientPreRender", root, tas.render_record)
		tas.var.recording = false
		tas.prompt("Recording stopped due to the minimize event! ($$#"..tostring(#tas.data).." ##frames)", 255, 100, 100)
	end
end
addEventHandler("onClientMinimize", root, tas.minimizeEvent)

-- // Stop recording on FPS change
function tas.changeFPSEvent(_, _, _, _, _, fps)
	if tas.var.recording then
		removeEventHandler("onClientPreRender", root, tas.render_record)
		tas.var.recording = false
		tas.prompt("Recording stopped because of FPS change "..tostring(tas.var.fps).." $$=> ##"..tostring(fps).."! ($$#"..tostring(#tas.data).." ##frames)", 255, 100, 100)
	end
end
addDebugHook("preFunction", tas.changeFPSEvent, {"setFPSLimit"})

-- // Overdrive 3 anti-sc
function tas.killOnSc(_, _, _, _, _, vehicle)
	
	-- wanna bother the driver? not possible anymore. this could've caused the driver to blow up, even with the cvar enabled
	if getPedOccupiedVehicle(localPlayer) == vehicle then
		if getVehicleController(vehicle) ~= localPlayer then
			return "skip"
		end
	end
	
	if not tas.settings.replaceBlow then return end -- LMFAO RETARD FORGOR ABOUT THIS
	if tas.var.playbacking then return end -- edit
	
	if getVehicleController(vehicle) == localPlayer then -- why would you tp the vehicle from passagers pov?
		setElementVelocity(vehicle, 0, 0, 0)
		setElementPosition(vehicle, 2940.2746, -2051.7504, 3.1619)
		setElementAngularVelocity(vehicle, 0, 0, 0) 
		setElementRotation(vehicle, 180, 0, 90) 
	end
	
	return "skip" -- tested under freeroam environment, doesn't work for passagers unless i force it!
end
addDebugHook("preFunction", tas.killOnSc, {"blowVehicle"})

function tas.globalRequestData(handleType, ...)

	local args = {...}

	if handleType == "save" then
	
		if tas.timers.recording then tas.prompt("Saving server-side failed, stop recording first!", 255, 100, 100) return end
		if #tas.data == 0 then 
			tas.prompt("Server saving failed, no $$data ##recorded.", 255, 100, 100) 
			triggerServerEvent("tas:onGlobalRequest", localPlayer, "failed_save")
			return 
		end
		
		-- // this shouldn't fail, IT SHOULDN'T!
		local handleSent = triggerLatentServerEvent("tas:onGlobalRequest", 10^6, false, localPlayer, "save", tas.data, tas.warps, args[1])
		
		if handleSent then
		
			-- // neither should this
			local handles = getLatentEventHandles()
			tas.var.saving_handle = handles[#handles]
			tas.var.saving_percent = getLatentEventStatus(tas.var.saving_handle).percentComplete
			
			tas.timers.saving_timer = setTimer(function()
			
				-- // but this one can, which is why we're performing some checks
				local current_handle = getLatentEventStatus(tas.var.saving_handle)
				if current_handle then 
					tas.var.saving_percent = current_handle.percentComplete
				end
				
				-- // if handle retrieval failed or it reached 100%, then remove restrictions
				if not current_handle or tas.var.saving_percent >= 100 then
					if tas.timers.saving_timer then
						if isTimer(tas.timers.saving_timer) then
							killTimer(tas.timers.saving_timer)
						end
						tas.timers.saving_timer = nil
						tas.var.saving_handle = nil
						tas.var.saving_percent = 0
					end
				end
				
			end, 200, 0)
			
			tas.prompt("Sending client data to server..", 255, 255, 100)
		
		else
			tas.prompt("Server saving failed, handle init. failed for an $$unknown ##reason.", 255, 100, 100)
		end
		
	elseif handleType == "load" then
	
		local isPrivated = (tas.settings.usePrivateFolder == true and "@") or ""
		local fileTarget = isPrivated .."saves/"..args[2]..".tas"
		
		if fileExists(fileTarget) then 
			fileDelete(fileTarget)
			tas.prompt("Warning! Existing file $$("..args[2]..".tas) ##has been deleted!", 255, 255, 100)
		end
		
		local load_file = fileCreate(fileTarget)
		if load_file then
			fileWrite(load_file, args[1])
			fileClose(load_file)
		end
		
		tas.prompt("File $$"..args[2]..".tas ##has been downloaded! Load it using $$/"..tas.registered_commands.load_record.." "..args[2].." ##!", 255, 255, 100)
		
		triggerServerEvent("tas:onGlobalRequest", localPlayer, "success_load")
		
	elseif handleType == "forcecancel" then
	
		if tas.var.saving_handle then
			cancelLatentEvent(tas.var.saving_handle)
			tas.var.saving_handle = nil
			tas.var.saving_percent = 0
		end
		
		if tas.timers.saving_timer then
			if isTimer(tas.timers.saving_timer) then
				killTimer(tas.timers.saving_timer)
			end
			tas.timers.saving_timer = nil
		end
		
		-- // baritone message
		tas.prompt("ok canceled", 255, 100, 255)
		
	end
end
addEvent("tas:onClientGlobalRequest", true)
addEventHandler("tas:onClientGlobalRequest", root, tas.globalRequestData)

function updateUserConfig()
	if fileExists("@config.json") then fileDelete("@config.json") end
	local save_cvar_file = fileCreate("@config.json")
	if save_cvar_file then
		fileWrite(save_cvar_file, toJSON(tas.settings))
		fileClose(save_cvar_file)
	end
end

-- // might come in handy for devs
function getTASData()
	return tas
end

-- // Nitro detection and modify stats (playback and load warp)
function tas.nos(vehicle, data)
	if vehicle then
		local nos_upgrade = getVehicleUpgradeOnSlot(vehicle, 8)
		if data ~= nil then
			if nos_upgrade == 0 then
				addVehicleUpgrade(vehicle, 1010)
				triggerServerEvent("tas:syncClient", vehicle, "nos", true)
			end
			setVehicleNitroCount(vehicle, data.c)
			setVehicleNitroLevel(vehicle, data.l)
			setVehicleNitroActivated(vehicle, data.a)
		else
			if nos_upgrade ~= 0 then
				removeVehicleUpgrade(vehicle, nos_upgrade)
				triggerServerEvent("tas:syncClient", vehicle, "nos", false)
			end
		end
	end
end

-- // Linear interpolation between 2 values
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

-- // Accurate get player vehicle
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
