local tas = {stik = 0, dtik = 0, tick_1 = 0, tick_2 = 0, pfr = 1, pbing = false,
			stopFinish = true,
			data = {},
			cmds = {playback = "playback",load_record = "loadr",autotas = "autotas"},
			keyz = {w = "accelerate", a = "vehicle_left",s = "brake_reverse",d = "vehicle_right",space = "handbrake",arrow_u = "steer_forward",arrow_d = "steer_back",arrow_r = "vehicle_right",arrow_l = "vehicle_left",lctrl = "vehicle_fire",lalt = "vehicle_secondary_fire"}}
			
function tas.init() for _,v in pairs(tas.cmds) do addCommandHandler(v, tas.commands) end end
addEventHandler("onClientResourceStart", resourceRoot, tas.init)

function tas.stop() tas.resetBinds() end
addEventHandler("onClientResourceStop", resourceRoot, tas.stop)

function tas.commands(cmd, ...) 
	local args = {...}
	local vehicle = _cveh(localPlayer)
	if cmd == tas.cmds.playback then
		if #tas.data < 1 then return end
		if tas.recording then return end
		if tas.pbing then
			removeEventHandler("onClientHUDRender", root, tas.render_playback)
			tas.pbing = false
			tas.resetBinds()
			tas.prompt("playback stop")
		else
			addEventHandler("onClientHUDRender", root, tas.render_playback)
			tas.pbing = true
			tas.pfr = 1
			tas.stik = getTickCount()
			tas.prompt("playback start")
		end
	elseif cmd == tas.cmds.load_record then
		if args[1] == nil then 
			tas.prompt("need file name") 
			return 
		end
		local lfile = (fileExists("@saves/"..args[1]..".tas") == true and fileOpen("@saves/"..args[1]..".tas")) or false
		if lfile then
			local file_data = fileRead(lfile, fileGetSize(lfile))
			local rline = tas.exp(file_data, "+run", "-run")
			if rline then
				local rdata = split(rline, "\n")
				if rdata and type(rdata) == "table" and #rdata > 1 then
					tas.data = {}
					for i=1, #rdata do
						local att = split(rdata[i], "|")
						local p = {loadstring("return "..att[2])()}
						local r = {loadstring("return "..att[3])()}
						local v = {loadstring("return "..att[4])()}
						local rv = {loadstring("return "..att[5])()}
						local n = {}
						local nret = {loadstring("return "..att[8])()}
						if #nret > 1 then 
							n = {c = nret[1], l = nret[2], a = (nret[3] == 1)}
						else
							n = nil
						end
						table.insert(tas.data, {tick = tonumber(att[1]), p = p, r = r, v = v, rv = rv, h = tonumber(att[6]), m = tonumber(att[7]), n = n, k = att[9]})
					end
				end
			end
			fileClose(lfile)
			tas.prompt("file loaded")
		else
			tas.prompt("file not found") 
			return
		end
	end
end

function tas.render_playback()
	local vehicle = _cveh(localPlayer)
	if vehicle and not isPedDead(localPlayer) then
		local current_tick = getTickCount()
		local real_time = current_tick - tas.stik
		local inbetweening = 0
		if tas.pfr < #tas.data or tas.data[tas.pfr] then
			while real_time > tas.data[tas.pfr].tick do
				tas.tick_1 = tas.data[tas.pfr].tick
				if tas.data[tas.pfr+2] then
					tas.tick_2 = tas.data[tas.pfr+1].tick
					tas.pfr = tas.pfr + 1
				else
					if tas.stopFinish then
						executeCommandHandler(tas.cmds.playback)
						return
					end
					break
				end
			end
		end
		inbetweening = tas.clamp(0, (real_time - tas.tick_1) / (tas.tick_2 - tas.tick_1), 1)
		local frame_data = tas.data[tas.pfr]
		local frame_data_next = tas.data[tas.pfr+1]
		setElementPosition(vehicle, tas.lerp(frame_data.p[1], frame_data_next.p[1], inbetweening), tas.lerp(frame_data.p[2], frame_data_next.p[2], inbetweening), tas.lerp(frame_data.p[3], frame_data_next.p[3], inbetweening))
		setElementRotation(vehicle, tas.lerp_angle(frame_data.r[1], frame_data_next.r[1], inbetweening), tas.lerp_angle(frame_data.r[2], frame_data_next.r[2], inbetweening), tas.lerp_angle(frame_data.r[3], frame_data_next.r[3], inbetweening))
		setElementVelocity(vehicle, unpack(frame_data.v))
		setElementAngularVelocity(vehicle, unpack(frame_data.rv))]
		setElementModel(vehicle, frame_data.m)
		setElementHealth(vehicle, frame_data.h)
		tas.nos(vehicle, frame_data.n)
		tas.resetBinds()
		for k,v in pairs(tas.keyz) do
			for _,h in ipairs(frame_data.k) do
				if k == h then
					setPedControlState(localPlayer, v, true)
				end
			end
		end
	else
		removeEventHandler("onClientHUDRender", root, tas.render_playback)
		tas.pbing = false
		tas.resetBinds()
		tas.prompt("playback error")
	end
end

function tas.resetBinds()
	for _,v in pairs(tas.keyz) do
		setPedControlState(localPlayer, v, false)
	end
end
function tas.prompt(text)
	return outputChatBox("TAS: "..text)
end
function tas.lerp(a, b, t) return a + t * (b - a) end
function tas.clamp(st, v, fn) return math.max(st, math.min(v, fn)) end
function tas.lerp_angle(start_angle, end_angle, progress)
    local start_angle = math.rad(start_angle)
    local end_angle = math.rad(end_angle)
    if math.abs(end_angle - start_angle) > math.pi then
        if end_angle > start_angle then
            start_angle = start_angle + 2*math.pi
        else
            end_angle = end_angle + 2*math.pi
        end
    end
    local angle = (1 - progress) * start_angle + progress * end_angle
    return math.deg(angle)
end
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
function _cveh(player)
	local vehicle = getPedOccupiedVehicle(player)
	if vehicle and getVehicleController(vehicle) == player then
		return vehicle
	end
	return false
end
function tas.exp(str, st, nd)
	local _, starter = string.find(str, st)
	local ender = string.find(str, nd)
	if starter and ender then
		return string.sub(str, starter+1, ender-1)
	end
end
