Script.Load("NS2_IO.lua")

local io = NS2_IO

if(not io) then
	return
end

Script.Load("lua/modentry.lua")
Script.Load("lua/Utility.lua")

if(not ModLoader) then
	ModLoader = {
		DisabledMods = {}
	}
end

local Mods = {}
local ActiveMods = {}

local function print(msg, ...)
	
	if(select('#', ...) == 0) then
		Shared.Message(msg)
	else
		Shared.Message(string.format(msg, ...))
	end
end

function ModLoader:Init()
	self.SV = SavedVariables("ModLoader", {"DisabledMods"}, self)
	self.SV:Load()
	
	self:ScannForMods()
	self:LoadMods()
	
	if(Client) then
		Event.Hook("Console_enablemod", function(modName) self:EnableMod(modName) end)
		Event.Hook("Console_disablemod", function(modName) self:DisableMod(modName) end)
		Event.Hook("Console_enableallmods", function() self:EnableAllMods() end) 
		Event.Hook("Console_disableallmods", function() self:DisableAllMods() end) 
		Event.Hook("Console_listmods", function() self:ListMods() end)
	end

end

function ModLoader:ListMods()
	for name,_ in pairs(Mods) do
		if(self.DisabledMods[name]) then
			print("%s : Disabled", name)
		else
			if(ActiveMods[name]) then
				print("%s : Enabled(Active)", name)
			else
				print("%s : Enabled(Inactive)", name)
			end
		end
	end
end

function ModLoader:EnableAllMods()
	
	for name,_ in pairs(Mods) do
		if(self.DisabledMods[name]) then
			self:EnableMod(name)
		end
	end
end

function ModLoader:DisableAllMods()
	
	for name,_ in pairs(Mods) do
		if(not self.DisabledMods[name]) then
			self:DisableMod(name)
		end
	end
end

function ModLoader:EnableMod(modName)
	
	if(not modName) then
		print("EnableMod: Need to specify the name of a mod to enable")
	 return
	end
	
	local name = modName:lower()
	
	if(not Mods[name]) then
		print("EnableMod: No mod named "..modName.." installed")
	 return
	end

	self.DisabledMods[name] = false
	
	self.SV:Save()
	
	print("Mod %s set to enabled a restart is require for this mod tobe loaded", modName)
end

function ModLoader:DisableMod(modName)
	
	if(not modName) then
		print("DisableMod: Need to specify the name of a mod to disable")
	 return
	end
	
	local name = modName:lower()
	
	if(not Mods[name]) then
		print("DisableMod: No mod named "..modName.." installed")
	 return
	end
	
	self.DisabledMods[name] = true
	
	self.SV:Save()
	
	if(ActiveMods[name]) then
		print("DisableMod: Mod %s set to disabled this mod will still be loaded for this session", modName)
	else
		print("DisableMod: Mod %s set to disabled", modName)
	end
end

function ModLoader:ScannForMods()

	for dirname,Source in pairs(io.FindDirectorys("/Mods/","")) do
 		
		local modinfopath = string.format("/Mods/%s/modinfo.lua", dirname)
		
		if(not Source:FileExists(modinfopath)) then
			print("Skiping mod directory \"%s\" that has no modinfo.lua in it", dirname)
		end
		
		Mods[dirname:lower()] = CreateModEntry(Source, dirname)
	end
	
	local SupportedArchives = {
		zip = true,
		["7z"] = true,
		rar = true
	}
	
	for fileName,Source in pairs(io.FindFiles("/Mods/","")) do
	
		if(SupportedArchives[(GetExtension(fileName) or ""):lower()]) then
			local success, archiveOrError = pcall(io.OpenArchive, Source, "/Mods/"..fileName)
	
			if(success) then
				if(archiveOrError:FileExists("modinfo.lua")) then
					local modname = StripExtension(fileName)
					
					Mods[modname:lower()] = CreateModEntry(archiveOrError, modname, true)
				else
					print("Skiping mod archive \"%s\" that has no modinfo.lua in it", fileName)
				end
			else
				print("error while opening mod archive %s :\n%s", fileName, archiveOrError)
			end
		end
		
	end
end

function ModLoader:OnClientLuaFinished()
	
	for modname,entry in pairs(Mods) do
		entry:OnClientLuaFinished()
	end
end

function ModLoader:OnServerLuaFinished()
	
	for modname,entry in pairs(Mods) do
		entry:OnServerLuaFinished()
	end
end

local VMName = (Server and "server") or "client"

function ModLoader:LoadMods()

	for modname,entry in pairs(Mods) do
		if(entry:LoadModinfo() and not self.DisabledMods[modname] and entry:CanLoadInVm(VMName)) then
			print("Loading mod: "..entry.Name)

			if(entry:Load()) then
				ActiveMods[modname] = entry
			end
		end
	end

end
