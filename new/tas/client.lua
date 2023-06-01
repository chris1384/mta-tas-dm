--[[
		* TAS - Recording Tool by chris1384 @2020
		* version 1.4
--]]

-- // the root of your problems
local tas = {
				-- // hardcoded variables, do not edit
				var = 	{
							start_tick = 0, -- begin tick (on start)
							tick_1 = 0, -- last frame tick
							tick_2 = 0, -- next frame tick (used for interpolation)
							play_frame = 1, -- used for table indexing
				
							recording = false,
							recording_fbf = false,
							fbf_switch = 0,
							
							rewinding = false, 
							
							playbacking = false,
						},
						
				data = {},
				
				settings = 	{
								startPrompt = true -- show resource initialization text on startup
								promptType = 1, -- how action messages should be rendered. 0: none, 1: chatbox (default), 2: dxText (useful if server uses wrappers) -- unused
							},
				timers = {},
			}
			
-- // Registered commands (edit to your liking)
local registered_commands = {	
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
local registered_keys = {
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
	
	for _,v in pairs(registered_commands) do
		addCommandHandler(v, tas.commands)
	end
	
end
addEventHandler("onClientResourceStart", resourceRoot, tas.init)


-- // Event Commands
function tas.commands(cmd, ...) 

	local args = {...}
	
	if cmd == registered_commands.record then
	
		if tas.var.playbacking then tas.prompt("[TAS] ##Recording failed, stop $$playbacking ##first!", 255, 100, 100) return end
		
		if tas.var.recording then
			removeEventHandler("onClientRender", root, tas.render_record)
			tas.var.recording = false
			tas.prompt("[TAS] ##Recording stopped! ($$"..tostring(#tas.data).." ##frames)", 100, 255, 100)
		else
			tas.data = {}
			tas.var.recording = true
			tas.var.start_tick = getTickCount()
			addEventHandler("onClientRender", root, tas.render_record)
			tas.prompt("[TAS] ##Recording frames..", 100, 255, 100)
		end
		
		
	elseif cmd == registered_commands.playback then
	
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
	end
end

-- // Recording
function tas.render_record()

	local vehicle = getPedOccupiedVehicle(localPlayer)
	
	if vehicle and getVehicleController(vehicle) == localPlayer then
	
		local current_tick = getTickCount()
		local real_time = current_tick - tas.var.start_tick
	
		local x, y, z = getElementPosition(vehicle)
		local rx, ry, rz = getElementRotation(vehicle)
		local vx, vy, vz = getElementVelocity(vehicle)
		local rvx, rvy, rvz = getElementAngularVelocity(vehicle)
		
		local health = getElementHealth(vehicle)
		local model = getElementModel(vehicle)
		
		local keys = {}
		for k in pairs(registered_keys) do
			if getKeyState(k) then
				table_insert(keys, k)
			end
		end
		
		table_insert(tas.data, 	{
										tick = real_time,
										p = {x, y, z},
										r = {rx, ry, rz},
										v = {vx, vy, vz},
										rv = {rvx, rvy, rvz},
										h = health,
										m = model,
										k = keys,
									}
					)
					
	end
end

-- // Playbacking
function tas.render_playback()

	local vehicle = getPedOccupiedVehicle(localPlayer)
	
	if vehicle and getVehicleController(vehicle) == localPlayer then
	
		local current_tick = getTickCount()
		local real_time = (current_tick - tas.var.start_tick)
		local inbetweening = 0
		
		dxDrawText("Total Frames: "..tostring(#tas.data), 600, 100, 0, 0)
		dxDrawText("Current Tick: "..tostring(current_tick).." | Real Time Tick: "..tostring(real_time), 600, 120, 0, 0)
		dxDrawText("Current Playback Frame: "..tostring(tas.var.play_frame).." | Last Tick: "..tostring(tas.var.tick_1).." | Upcoming Tick: "..tostring(tas.var.tick_2), 600, 140, 0, 0)
		dxDrawText("Inbetween: "..tostring(inbetweening), 600, 160, 0, 0)

		if tas.var.play_frame < #tas.data or tas.data[tas.var.play_frame] then
			while real_time > tas.data[tas.var.play_frame].tick do
				tas.var.tick_1 = tas.data[tas.var.play_frame].tick
				if tas.data[tas.var.play_frame+2] then
					tas.var.tick_2 = tas.data[tas.var.play_frame+1].tick
					tas.var.play_frame = tas.var.play_frame + 1
				else
					break
				end
			end
		end
		
		inbetweening = math_max(0, math_min((real_time - tas.var.tick_1) / (tas.var.tick_2 - tas.var.tick_1), 1))
		
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
		
		local vx, vy, vz = unpack(frame_data.v)
		setElementVelocity(vehicle, vx, vy, vz)
		
		local rvx, rvy, rvz = unpack(frame_data.rv)
		setElementAngularVelocity(vehicle, rvx, rvy, rvz)
		
		setElementModel(vehicle, frame_data.m)
		setElementHealth(vehicle, frame_data.h)
		
		tas.resetBinds()
		for k,v in pairs(registered_keys) do
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
	for _,v in pairs(registered_keys) do
		setPedControlState(localPlayer, v, false)
	end
end

-- // Command messages
function tas.prompt(text, r, g, b)
	local text = string_gsub(text, "%#%#", "#FFFFFF")
	local text = string_gsub(text, "%$%$",  string.format("#%.2X%.2X%.2X", r, g, b))
	return outputChatBox(text, r, g, b, true)
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

--[[ -- unused
function tas.float(number)
	return math_floor( number * 1000 ) * 0.01
end
]]
