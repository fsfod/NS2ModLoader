local EntryMetaTable = {
	__index = ModEntry,
}

function CreateModEntry(rootDirectory, name)
	
	local ModData = { 
		Name = name,
		InternalName = name:lower(),
		GameFileSystemPath = rootDirectory,
		IsArchive = false,
	}

  ModData.Path = pathInSource or ""


	return setmetatable(ModData, EntryMetaTable)
end


ModLoader.Embeded = true

function ModLoader:ScannForMods()
  
  local matchingFiles = {}
  
  Shared.GetMatchingFileNames("Mods/modinfo.lua", true, matchingFiles)
	
	for _,path in ipairs(matchingFiles) do
	  local dirName = string.match(path, "Mods/([^%/]+)/modinfo.lua")
	  
		if(dirName) then
			self:AddModFromDir("Mods/"..dirName, dirName, true)
		else
			Shared.Message("ModLoader.ScannForMods: not a valid mod "..path)
		end
	end
end

function ModLoader:AddModFromDir(dirPath, name, optional, defaultDisabled)
  local mod = CreateModEntry(dirPath, name)
  
  local name = mod.InternalName
    
  if(optional) then
    if(defaultDisabled == nil) then
      defaultDisabled = self.DisabledMods[name] == true
    end
    
    self.DisabledMods[name] = Client.GetOptionBoolean("ModLoader/Disabled/"..name, defaultDisabled)
  else
    mod.Required = true
  end
  
  self.Mods[name] = mod
end

function ModLoader:LoadModFromDir(dirPath, name, optional, defaultDisabled)
  local mod = CreateModEntry(dirPath, name)
  
  local name = mod.InternalName
    
  if(optional) then
    if(defaultDisabled == nil) then
      defaultDisabled = self.DisabledMods[name] == true
    end
    
    self.DisabledMods[name] = Client.GetOptionBoolean("ModLoader/Disabled/"..name, defaultDisabled)
  else
    mod.Required = true
  end
  
  if(mod:LoadModinfo()) then
    self.Mods[name] = mod
    
    if(not self.DisabledMods[name]) then
			if(optional) then
				Shared.Message("Loading mod "..mod.Name)
			end
      self.OrderedActiveMods[#self.OrderedActiveMods+1] = mod:Load() and mod
    end
  end
end

function ModLoader:ModEnableStateChanged(name)
  Client.SetOptionBoolean("ModLoader/Disabled/"..name, self.DisabledMods[name])
end

local RequiredFieldList ={
	ValidVM = false,
	EngineBuild = "number",
	ModTableName = "string",
}

local OptionalFieldList = {
	SavedVaribles = "table",
	MainScript = "string",
	ScriptList = "table",
	ScriptOverrides = "table",
	
	CanLateLoad = "boolean",
}

if(not __ModPath) then

function ModEntry:LoadModinfo()

  //wtb a Script.Load that takes an enviroment to load the script
  for name,_ in pairs(OptionalFieldList) do
    _G[name] = nil
  end

  for name,_ in pairs(RequiredFieldList) do
    _G[name] = nil
  end

  self:RunLuaFile("modinfo.lua")

  local modinfo = {}

  for name,_ in pairs(OptionalFieldList) do
    modinfo[name] = _G[name]
  end

  for name,_ in pairs(RequiredFieldList) do
    modinfo[name] = _G[name]
  end
  
  self.LoadState = LoadState.ModinfoLoaded

  return self:ProcessModInfo(modinfo)
end

end

function ModEntry:LoadMainScript()
	local fields = self.Modinfo

  self:RunLuaFile(self.Modinfo.MainScript)

	return self:MainLoadPhase()
end

function ModEntry:MainLoadPhase()
  
  local fields = self.Modinfo
	local ModTable = _G[fields.ModTableName]

	if(not ModTable) then
	  self.LoadState = LoadState.ModTableMissing

		Print(self.Name.." modtable could not be found after loading")
	 return false
	end
	
	self.ModTable = ModTable
	
	self:InjectFunctions()
	
	self:CallModFunction("OnLoad")
  
  return true
end