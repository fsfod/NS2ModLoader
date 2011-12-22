//
//   Created by:   fsfod
//

local EntryMetaTable = {
	__index = ModEntry,
}

local function CreateModEntry(rootDirectory, name)
	
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
	
	//7zip archive system is not loaded
	if(not OpenArchive) then
	  return
	end
	
  local SupportedArchives = {
		  [".zip"] = true,
		  [".rar"] = true,
		  [".7ip"] = true,
	}
	
	matchingFiles = {}
	
	Shared.GetMatchingFileNames("/Mods/*.*", false, matchingFiles)

	--scan for mods are contained in archives that are in our "Mods" folder
	for _,path in ipairs(matchingFiles) do	
	  local fileName = GetFileNameFromPath(path)
	
		if(SupportedArchives[(GetExtension(fileName) or ""):lower()]) then
			local success, archiveOrError = pcall(OpenArchive, path)
	
			if(success) then
			  
				if(archiveOrError:FileExists("modinfo.lua")) then
					self:AddModEntry(archiveOrError, StripExtension(fileName), true)
				else
				  
				  local dirlist = archiveOrError:FindDirectorys("", "")
				  local modname = dirlist[1]
				  
				  --if theres no modinfo.lua in the root of the archive see if the archive contains a single directory that has a modinfo.lua in it
				  if(#dirlist == 1 and archiveOrError:FileExists(modname.."/modinfo.lua")) then
				    self:AddModEntry(archiveOrError, modname, true, modname.."/")
				  else
				    RawPrint("Skiping mod archive \"%s\" that has no modinfo.lua in it", fileName)
				  end
				end
				
			else
				RawPrint("error while opening mod archive %s :\n%s", fileName, archiveOrError)
			end
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
    
    //sigh GetOption stuff really needs tobe moved to shared.  just treat server mods as always enabled 
    self.DisabledMods[name] = (Client or false)  and Client.GetOptionBoolean("ModLoader/Disabled/"..name, defaultDisabled)
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
	Dependencies = true,
	CanLateLoad = "boolean",
}

if(not __ModPath) then

function ModEntry:LoadModinfo()

  if(self.Modinfo) then
    return true
  end

  //wtb a Script.Load that takes an enviroment to load the script
  for name,_ in pairs(OptionalFieldList) do
    _G[name] = nil
  end

  for name,_ in pairs(RequiredFieldList) do
    _G[name] = nil
  end

  self:RunLuaFile("modinfo.lua")

  local modinfo = setmetatable({}, self.ChangeCaseMT)

  for name,_ in pairs(OptionalFieldList) do
    modinfo[name] = _G[name]
  end

  for name,_ in pairs(RequiredFieldList) do
    modinfo[name] = _G[name]
  end
  
  self.LoadState = LoadState.ModinfoLoaded

  return self:ProcessModInfo(modinfo)
end

function ModEntry:LoadMainScript()
	local fields = self.Modinfo

  self:RunLuaFile(self.Modinfo.MainScript)

	return self:MainLoadPhase()
end

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