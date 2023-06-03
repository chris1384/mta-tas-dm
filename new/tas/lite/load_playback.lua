local tas = {stik = 0, dtik = 0, tk1 = 0, tk2 = 0, pfr = 1, pbing = false, stopFinish = true, data = {}, cmds = {pbk = "playback",lrec = "loadr"}, keyz = {w = "accelerate", a = "vehicle_left",s = "brake_reverse",d = "vehicle_right",space = "handbrake",arrow_u = "steer_forward",arrow_d = "steer_back",arrow_r = "vehicle_right",arrow_l = "vehicle_left",lctrl = "vehicle_fire",lalt = "vehicle_secondary_fire"}}
function tas.init() for _,v in pairs(tas.cmds) do addCommandHandler(v, tas.commands) end end addEventHandler("onClientResourceStart", resourceRoot, tas.init)
function tas.stop() tas.rbnd() end addEventHandler("onClientResourceStop", resourceRoot, tas.stop)
function tas.commands(cmd, nm) local vehicle = _cveh(localPlayer) if cmd == tas.cmds.pbk then if #tas.data < 1 then return end if tas.recording then return end if tas.pbing then removeEventHandler("onClientHUDRs2", root, tas.rs2_pbk) tas.pbing = false tas.rbnd() tas.cht("playback stop") else addEventHandler("onClientHUDRs2", root, tas.rs2_pbk) tas.pbing = true tas.pfr = 1 tas.stik = getTickCount() tas.cht("playback start") end elseif cmd == tas.cmds.lrec then if nm == nil then tas.cht("need file name") return end local lfile = (fileExists("@saves/"..nm..".tas") == true and fileOpen("@saves/"..nm..".tas")) or false if lfile then local file_data = fileRead(lfile, fileGetSize(lfile)) local rline = tas.exp(file_data, "+run", "-run") if rline then local rdata = split(rline, "\n") if rdata and type(rdata) == "table" and #rdata > 1 then tas.data = {} for i=1, #rdata do  local att = split(rdata[i], "|") local p = {loadstring("return "..att[2])()} local r = {loadstring("return "..att[3])()} local v = {loadstring("return "..att[4])()} local rv = {loadstring("return "..att[5])()} local n = {} local nret = {loadstring("return "..att[8])()} if #nret > 1 then n = {c = nret[1], l = nret[2], a = (nret[3] == 1)} else n = nil end table.insert(tas.data, {tick = tonumber(att[1]), p = p, r = r, v = v, rv = rv, h = tonumber(att[6]), m = tonumber(att[7]), n = n, k = att[9]}) end end end fileClose(lfile) tas.cht("file loaded") else tas.cht("file not found")  return end end end
function tas.rs2_pbk() local vehicle = _cveh(localPlayer) if vehicle and not isPedDead(localPlayer) then local ctik = getTickCount() local rtime = ctik - tas.stik local inbw = 0 if tas.pfr < #tas.data or tas.data[tas.pfr] then while rtime > tas.data[tas.pfr].tick do tas.tk1 = tas.data[tas.pfr].tick if tas.data[tas.pfr+2] then tas.tk2 = tas.data[tas.pfr+1].tick tas.pfr = tas.pfr + 1 else if tas.stopFinish then executeCommandHandler(tas.cmds.pbk) return end break end end end inbw = tas.clp(0, (rtime - tas.tk1) / (tas.tk2 - tas.tk1), 1) local fdat = tas.data[tas.pfr] local fdatn = tas.data[tas.pfr+1] setElementPosition(vehicle, tas.lerp(fdat.p[1], fdatn.p[1], inbw), tas.lerp(fdat.p[2], fdatn.p[2], inbw), tas.lerp(fdat.p[3], fdatn.p[3], inbw)) setElementRotation(vehicle, tas.lerpa(fdat.r[1], fdatn.r[1], inbw), tas.lerpa(fdat.r[2], fdatn.r[2], inbw), tas.lerpa(fdat.r[3], fdatn.r[3], inbw)) setElementVelocity(vehicle, unpack(fdat.v)) setElementAngularVelocity(vehicle, unpack(fdat.rv))] setElementModel(vehicle, fdat.m) setElementHealth(vehicle, fdat.h) tas.nos(vehicle, fdat.n) tas.rbnd() for k,v in pairs(tas.keyz) do for _,h in ipairs(fdat.k) do if k == h then setPedControlState(localPlayer, v, true) end end end else removeEventHandler("onClientHUDRs2", root, tas.rs2_pbk) tas.pbing = false tas.rbnd() tas.cht("playback error") end end
function tas.rbnd() for _,v in pairs(tas.keyz) do setPedControlState(localPlayer, v, false) end end
function tas.cht(text) return outputChatBox("TAS: "..text) end
function tas.lerp(a, b, t) return a + t * (b - a) end
function tas.clp(st, v, fn) return math.max(st, math.min(v, fn)) end
local pi = math.pi
function tas.lerpa(s_a, e_a, pg) local s_a = math.rad(s_a) local e_a = math.rad(e_a) if math.abs(e_a - s_a) > pi then if e_a > s_a then s_a = s_a + 2*pi else e_a = e_a + 2*pi end end return math.deg((1 - pg) * s_a + pg * e_a) end
function tas.nos(vehicle, data) if vehicle then local noup = getVehicleUpgradeOnSlot(vehicle, 8) if data ~= nil then if noup == 0 then addVehicleUpgrade(vehicle, 1010) end setVehicleNitroCount(vehicle, data.c) setVehicleNitroLevel(vehicle, data.l) setVehicleNitroActivated(vehicle, data.a) else if noup ~= 0 then removeVehicleUpgrade(vehicle, noup) end end end end
function _cveh(player) local vehicle = getPedOccupiedVehicle(player) if vehicle and getVehicleController(vehicle) == player then return vehicle end return false end
function tas.exp(str, st, nd) local _, s1 = string.find(str, st) local s2 = string.find(str, nd) if s1 and s2 then return string.sub(str, s1+1, s2-1) end end
