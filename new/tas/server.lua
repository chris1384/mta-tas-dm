--[[
		* TAS - Recording Tool by chris1384 @2020
		* version 1.4.3
--]]

local tas = {
	var = {
		cooldowns = {},
		handles = {},
		isCreatingDummy = false,
	},
	settings = {
	
		-- // Saving and loading records
		
		enableGlobalAccess = true, -- enable global access for files to be saved and loaded by players (useful for sharing between players)
		saveACLRequirement = {"Console", "Admin", "SuperModerator"}, -- the ACL Group requirements for a player to save TAS files serverside.
		--saveACLOverwriteRequirement = {"Console", "Admin"}, -- [UNUSED] the ACL Group requirements for a player to overwrite previously saved TAS file serverside.
		loadACLRequirement = {"Everyone"}, -- same as saving (must be logged in)
		
		globalAnnouncements = true, -- enable server announcements whenever a player is saving/loading a file
		
		saveWarpData = true, -- save warp data to TAS files
		-- //
	},
}

-- // Registered server commands
tas.registered_commands = {	
	load_record_global = "loadrg",
	save_record_global = "saverg",
	force_cancel = "forcecancel",
}

-- // Initialization
function tas.init()
	for _,v in pairs(tas.registered_commands) do
		addCommandHandler(v, tas.commands)
	end
end
addEventHandler("onResourceStart", resourceRoot, tas.init)

function tas.commands(player, cmd, ...)

	local args = {...}
	
	local r, g, b = getPlayerNametagColor(player)
	local full_name = string.format("#%.2X%.2X%.2X", r, g, b) .. getPlayerName(player)

	if cmd == tas.registered_commands.save_record_global then
	
		if tas.settings.enableGlobalAccess ~= true then tas.prompt("This command has been disabled!", player, 255, 100, 100) return end
		
		if tas.var.cooldowns[player] ~= nil then tas.prompt("Please wait for your record to be $$saved##/$$loaded##!", player, 255, 100, 100) return end
		
		if args[1] == nil then 
			tas.prompt("Server saving failed, please specify a $$name ##for your file!", player, 255, 100, 100) 
			tas.prompt("Example: $$/"..tas.registered_commands.save_record_global.." od3", player, 255, 100, 100) 
			return 
		end
		
		local permissionCheck = false
		
		local account = getPlayerAccount(player)
		if (account and not isGuestAccount(account)) then
			for index,aclGroup in ipairs(tas.settings.saveACLRequirement) do
				if isObjectInACLGroup("user."..getAccountName(account), aclGetGroup(aclGroup)) then
					permissionCheck = true
					break
				end
			end
		end
		
		if not permissionCheck then tas.prompt("You don't have access to use this command!", player, 255, 100, 100) return end
		
		local fileTarget = "saves/"..args[1]..".tas"
		if fileExists(fileTarget) then tas.prompt("Server saving failed, file with the same name $$already ##exists!", player, 255, 100, 100) return end
		
		tas.prompt("Requesting client for data..", player, 100, 255, 100)
		setTimer(triggerClientEvent, 500, 1, player, "tas:onClientGlobalRequest", player, "save", tostring(args[1]))
		tas.var.cooldowns[player] = true
		
	elseif cmd == tas.registered_commands.load_record_global then
	
		if tas.settings.enableGlobalAccess ~= true then tas.prompt("This command has been disabled!", player, 255, 100, 100) return end
		
		if tas.var.cooldowns[player] ~= nil then tas.prompt("Please wait for your record to be saved/loaded!", player, 255, 100, 100) return end
		
		if args[1] == nil then 
			tas.prompt("Server loading failed, please specify a $$name ##for your file!", player, 255, 100, 100) 
			tas.prompt("Example: $$/"..tas.registered_commands.load_record_global.." ar2", player, 255, 100, 100) 
			return 
		end
		
		local permissionCheck = false
		
		local account = getPlayerAccount(player)
		if (account and not isGuestAccount(account)) then
			for index,aclGroup in ipairs(tas.settings.loadACLRequirement) do
				if isObjectInACLGroup("user."..getAccountName(account), aclGetGroup(aclGroup)) then
					permissionCheck = true
					break
				end
			end
		end
		
		if not permissionCheck then tas.prompt("You don't have access to use this command!", player, 255, 100, 100) return end
		
		local fileTarget = "saves/"..args[1]..".tas"
		if not fileExists(fileTarget) then tas.prompt("Server loading failed, file does $$not ##exist!", player, 255, 100, 100) return end
		
		local load_file = fileOpen(fileTarget)
		
		if load_file then
			local load_size = fileGetSize(load_file)
			local load_data = fileRead(load_file, load_size)
			
			local handleLoad = triggerLatentClientEvent(player, "tas:onClientGlobalRequest", 10^6, false, player, "load", load_data, args[1])
			
			if handleLoad then
				local handles = getLatentEventHandles(player)
				tas.var.handles[player] = handles[#handles]
			end
			
			if tas.settings.globalAnnouncements then
				tas.prompt(full_name.." ##has requested file '$$"..args[1]..".tas##'! Sending file..", root, 255, 255, 100)
			else
				tas.prompt("Requested file '$$"..args[1]..".tas##' for downloading! Sending file..", player, 255, 255, 100)
			end
			
			fileClose(load_file)
			
			tas.var.cooldowns[player] = true
		else
			tas.prompt("Error loading the file. (not exising/reading file not permitted)", player, 255, 255, 100)
		end
	
	elseif cmd == tas.registered_commands.force_cancel then
	
		if tas.var.handles[player] then
			cancelLatentEvent(tas.var.handles[player])
		end
		tas.var.cooldowns[player] = nil
		triggerClientEvent(player, "tas:onClientGlobalRequest", player, "forcecancel")
	end
end

addEvent("tas:onGlobalRequest", true)
addEventHandler("tas:onGlobalRequest", root, function(handleType, ...)

	local global_data = {...}
	
	local player = source
	local r, g, b = getPlayerNametagColor(player)
	local full_name = string.format("#%.2X%.2X%.2X", r, g, b) .. getPlayerName(player)
	
	-- // Saving
	if handleType == "save" then

		local tas_data = global_data[1]
		local tas_warps = global_data[2]
		local tas_fileName = global_data[3]
		
		if #tas_data > 0 then
	
			local fileTarget = "saves/"..tas_fileName..".tas"
			
			-- using fileExists shouldn't be used anymore as it's already handled in the command part
			-- under weird circumstances, errors can still happen and wreck everything up. for safety, this check is also done here
			if fileExists(fileTarget) then tas.prompt("Server saving error, file with the same name $$already ##exists!", player, 255, 100, 100) return end
			
			local save_file = fileCreate(fileTarget)
			if save_file then
			
				-- // Header
				fileWrite(save_file, "# "..tas_fileName..".tas file created on "..os.date().."\n")
				fileWrite(save_file, "# Author: "..string.gsub(full_name, "#%x%x%x%x%x%x", "").." | Frames: "..tostring(#tas_data).." | Warps: "..tostring(#tas_warps).."\n\n")
				-- //
				
				-- // Recording part
				fileWrite(save_file, "+run\n")
				
				for i=1, #tas_data do
				
					local run = tas_data[i]
					local nos = "-1"
					
					if run.n then
						local active = ((run.n.a == true) and "1") or "0"
						nos = tostring(run.n.c)..","..tostring(tas.float(run.n.l))..",".. active
					end
					
					local keys = ""
					if run.k then
						keys = table.concat(run.k, ",")
					end
					
					fileWrite(save_file, string.format("%s|%s,%s,%s|%s,%s,%s|%s,%s,%s|%s,%s,%s|%d|%d|%s|%s", tas.float(run.tick), tas.float(run.p[1]), tas.float(run.p[2]), tas.float(run.p[3]), tas.float(run.r[1]), tas.float(run.r[2]), tas.float(run.r[3]), tas.float(run.v[1]), tas.float(run.v[2]), tas.float(run.v[3]), tas.float(run.rv[1]), tas.float(run.rv[2]), tas.float(run.rv[3]), math.max(run.h), run.m, nos, keys).."\n")
				end
				
				fileWrite(save_file, "-run\n")
				-- //
				
				-- // Warps part
				if #tas_warps > 0 and tas.settings.saveWarpData then
					fileWrite(save_file, "+warps\n")
					for i=1, #tas_warps do
					
						local warp = tas_warps[i]
						local nos = "-1"
						
						if warp.n then
							local active = ((warp.n.a == true) and "1") or "0"
							nos = tostring(warp.n.c)..","..tostring(tas.float(warp.n.l))..",".. active
						end
						
						if warp.tick then
							fileWrite(save_file, string.format("%d|%s|%s,%s,%s|%s,%s,%s|%s,%s,%s|%s,%s,%s|%d|%d|%s", warp.frame, tas.float(warp.tick), tas.float(warp.p[1]), tas.float(warp.p[2]), tas.float(warp.p[3]), tas.float(warp.r[1]), tas.float(warp.r[2]), tas.float(warp.r[3]), tas.float(warp.v[1]), tas.float(warp.v[2]), tas.float(warp.v[3]), tas.float(warp.rv[1]), tas.float(warp.rv[2]), tas.float(warp.rv[3]), warp.h, warp.m, nos).."\n")
						end
						
					end
					fileWrite(save_file, "-warps")
				end
				-- //
				
				fileClose(save_file)
			
			end
			
			if tas.settings.globalAnnouncements then
				tas.prompt(full_name.." ##has saved $$'saves/"..tas_fileName..".tas' ##to the server!", root, 255, 255, 100)
			else
				tas.prompt("$$'saves/"..tas_fileName..".tas' ##has been sent to the server successfully!", player, 255, 255, 100)
			end
			
		else
			tas.prompt("Server saving error, no $$data ##found!", player, 255, 100, 100)
		end
		
		tas.var.cooldowns[player] = nil
	
	elseif handleType == "success_load" then
		tas.var.handles[player] = nil
		tas.var.cooldowns[player] = nil
	
	elseif handleType == "failed_save" then
		tas.var.cooldowns[player] = nil
	end
	-- //
end)


-- // Use the event given by the Race Default
addEvent("onRaceStateChanging")
addEventHandler("onRaceStateChanging", root, function(new)

	local everyone = getElementsByType("player")
	
	if new == "Running" then
		triggerClientEvent(everyone, "tas:triggerCommand", resourceRoot, "Started")
	elseif new == "NoMap" or new == "PostFinish" then
		triggerClientEvent(everyone, "tas:triggerCommand", resourceRoot, "Stop")
	end
	
end)

-- // Model Change Resync with clients (might break up) | NOS syncing
addEvent("tas:syncClient", true)
addEventHandler("tas:syncClient", root, function(event, value)

	local vehicle = source
	
	if event == "vehiclechange" then
		setElementModel(vehicle, value)
	elseif event == "nos" then
		if value == true then
			addVehicleUpgrade(vehicle, 1010)
		else
			removeVehicleUpgrade(vehicle, getVehicleUpgradeOnSlot(vehicle, 8))
		end
	end
end)


-- // Semi-wrapper for edf vehicle creator
addEvent("tas:edfCreate", true)
addEventHandler("tas:edfCreate", root, function()
	tas.var.isCreatingDummy = true
end)

-- // Event triggered by editor
addEvent("onElementCreate")
addEventHandler("onElementCreate", root, function()
	local element = source
	if getElementType(element) == "vehicle" then
		if tas.var.isCreatingDummy then -- yeah we sure are applying these down here
		
			-- // Apply position and rotation
			local x, y, z = getElementPosition(source)
			exports.edf:edfSetElementPosition(source, x, y, z)
			local rx, ry, rz = getElementRotation(source)
			exports.edf:edfSetElementRotation(source, rx, ry, rz, "ZYX")
			
			-- // Tuning stuff
			exports.edf:edfSetElementProperty(source, "collisions", "false")
			exports.edf:edfSetElementProperty(source, "locked", "true")
			exports.edf:edfSetElementProperty(source, "frozen", "true")
			exports.edf:edfSetElementProperty(source, "upgrades", {1097, 1010})
			exports.edf:edfSetElementProperty(source, "plate", "TASDUMMY")
			
			-- // Set custom ID, fuckin override everything idc
			local testID = 1
			while getElementByID("TAS:Dummy ("..tostring(testID)..")") do
				testID = testID + 1
			end
			local newID = "TAS:Dummy ("..tostring(testID)..")"
			setElementID(source, newID)
			setElementData(source, "id", newID)
			setElementData(source, "me:ID", newID)
			setElementData(source, "me:autoID", true)
			exports.edf:edfSetElementProperty(source, "id", newID)
			
			-- // Pretty color
			setVehicleColor(source, 255, 0, 0, 255, 255, 255, 255, 0, 0, 255, 255, 255)
			
			-- // We finished? Hell yeah, disable this so we don't apply dummy properties
			tas.var.isCreatingDummy = false
		end
	end
end)

addEventHandler("onPlayerQuit", root, function()
	local player = source
	tas.var.cooldowns[player] = nil
	tas.var.handles[player] = nil
end)

-- // Command messages
function tas.prompt(text, element, r, g, b)
	if type(text) ~= "string" then return end
	if not (r and g and b) then return end
	return outputChatBox("[SERVER-TAS] #FFFFFF"..string.gsub(string.gsub(text, "%#%#", "#FFFFFF"), "%$%$", string.format("#%.2X%.2X%.2X", r, g, b)), element, r, g, b, true)
end

function tas.float(number)
	return math.floor( number * 1000 ) * 0.001
end
