--[[
		* TAS - Recording Tool by chris1384 @2020
		* version 1.4
--]]

local tas = {
	var = {
		cooldowns = {},
	},
	settings = {
	
		-- // Saving and loading records
		
		enableGlobalAccess = true, -- enable global access for files to be saved and loaded by players (useful for sharing between players)
		saveACLRequirement = {"Console", "Admin", "SuperModerator"}, -- the ACL Group requirements for a player to save TAS files serverside.
		--saveACLOverwriteRequirement = {"Console", "Admin"}, -- [UNUSED] the ACL Group requirements for a player to overwrite previously saved TAS file serverside.
		loadACLRequirement = {"Everyone"}, -- same as saving (must be logged in)
		loadingCooldown = 5000, -- set a delay for players to load a certain file.
		
		saveWarpData = true, -- save warp data to TAS files
		-- //
	},
}

-- // Registered server commands
tas.registered_commands = {	
	load_record_global = "loadrg",
	save_record_global = "saverg",
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

	if cmd == tas.registered_commands.save_record_global then
	
		if tas.settings.enableGlobalAccess ~= true then tas.prompt("This command has been disabled!", player, 255, 100, 100) return end
		
		if tas.var.cooldowns[player] ~= nil then tas.prompt("Please wait for your record to be saved/loaded!", player, 255, 100, 100) return end
		
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
			
			triggerLatentClientEvent(player, "tas:onClientGlobalRequest", 10^6, false, player, "load", load_data, args[1])
			
			tas.prompt("Server is sending file data to client, please wait!", player, 255, 255, 100)
			
			fileClose(load_file)
			
			tas.var.cooldowns[player] = true
		else
			tas.prompt("Error loading the file. (not exising/reading file not permitted)", player, 255, 255, 100)
		end
		
		setTimer(function() tas.var.cooldowns[player] = nil end, tas.settings.loadingCooldown, 1)
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
				
				fileWrite(save_file, string.format("%d|%s,%s,%s|%s,%s,%s|%s,%s,%s|%s,%s,%s|%d|%d|%s|%s", run.tick, tas.float(run.p[1]), tas.float(run.p[2]), tas.float(run.p[3]), tas.float(run.r[1]), tas.float(run.r[2]), tas.float(run.r[3]), tas.float(run.v[1]), tas.float(run.v[2]), tas.float(run.v[3]), tas.float(run.rv[1]), tas.float(run.rv[2]), tas.float(run.rv[3]), run.h, run.m, nos, keys).."\n")
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
						fileWrite(save_file, string.format("%d|%d|%s,%s,%s|%s,%s,%s|%s,%s,%s|%s,%s,%s|%d|%d|%s", warp.frame, warp.tick, tas.float(warp.p[1]), tas.float(warp.p[2]), tas.float(warp.p[3]), tas.float(warp.r[1]), tas.float(warp.r[2]), tas.float(warp.r[3]), tas.float(warp.v[1]), tas.float(warp.v[2]), tas.float(warp.v[3]), tas.float(warp.rv[1]), tas.float(warp.rv[2]), tas.float(warp.rv[3]), warp.h, warp.m, nos).."\n")
					end
					
				end
				fileWrite(save_file, "-warps")
			end
			-- //
			
			fileClose(save_file)
		
		end
		
		tas.prompt(full_name.." ##has saved $$'saves/"..tas_fileName..".tas' ##to the server!", root, 255, 255, 100)
		
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

-- // Model Change Resync with clients (might break up)
addEvent("tas:onModelChange", true)
addEventHandler("tas:onModelChange", root, function(model)
	setElementModel(source, model)
end)

addEventHandler("onPlayerQuit", root, function()
	local player = source
	tas.var.cooldowns[player] = nil
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
