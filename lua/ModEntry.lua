ModEntry = {}

local xpcall = xpcall

if(decoda_output) then
  xpcall = function(func, exp, ...)
    return true,func(...)
  end
end

LoadState = {
	ModinfoLoadError    = -1,
	ModinfoSyntaxError  = -2,
	ModinfoRunError     = -3,
	ModinfoFieldMissing = -4,
	ModinfoFieldInvalid = -5,
	ModTableNameInUse   = -6,
	DependencyMissing   = -7,
	DependencyHasError  = -8,
	ModTableMissing     = -9,

	Disabled = 0,
	ModinfoLoaded = 1,
	FullyLoaded = 2,
}

local EntryMetaTable = {
	__index = ModEntry,
}

local IsRootFileSource = NS2_IO and NS2_IO.IsRootFileSource

local function PrintStackTrace(err) 
	Shared.Message(debug.traceback(err, 1))
end

function CreateModEntry(Source, dirname, IsArchive, pathInSource)
	
	local ModData = {
		FileSource = Source, 
		Name = dirname,
		InternalName = dirname:lower(),
		IsArchive = IsArchive,
		LoadState = 0,
	}

	local IsFromRootSource = IsRootFileSource(Source)

	if(IsFromRootSource) then
		ModData.GameFileSystemPath = "Mods/"..dirname
		//Source:MountFiles(ModData.GameFileSystemPath, "")
	end

	if(IsArchive) then
		ModData.Path = pathInSource or ""
	else
		ModData.Path = "/Mods/"..dirname.."/"
	end

	return setmetatable(ModData, EntryMetaTable)
end

local ChangeCaseMT = {
  __newindex = function(tbl, key, value) 
    rawset(tbl, key:lower(), value) 
  end,
  
  __index = function(tbl, key) 
    return rawget(tbl, key:lower()) 
  end,
}

function ModEntry:ConvertDependencysList(list)

  local deps = {}

  for _,name in ipairs(list) do
    if(type(name) == "string" and name ~= "") then
      deps[name:lower()] = true
    end
  end
  
  return next(deps) and deps
end

function ModEntry:LoadModinfo()

	local Source = self.FileSource
	
	local success, chunkOrError = pcall(Source.LoadLuaFile, Source, self.Path.."modinfo.lua")
	//local success, chunkOrError = pcall(loadfile, string.format("modloader/mods/%s/modinfo.lua", self.Name))

	if(not success) then
	  self.LoadState = LoadState.ModinfoLoadError
		self:PrintError("error while trying to read %s's modinfo file:\n%s", self.Name, chunkOrError)
	 return false
	end

	if(type(chunkOrError) == "string") then
	  self.LoadState = LoadState.ModinfoParseError

		self:PrintError("error while parsing %s's modinfo file:\n%s", self.Name, chunkOrError)
	 return false
	end
		
	local fields = setmetatable({}, ChangeCaseMT)
		setfenv(chunkOrError, fields)

	local success, msg = pcall(chunkOrError)
		 
	if(not success) then
	  self.LoadState = LoadState.ModinfoRunError
		self:PrintError("error while running %s's modinfo file:\n%s", self.Name, msg)	
		
		return false
	end

	self.Modinfo = fields

	self.Valid = true

	if(fields.Dependencys) then
    self.Dependencys = self:ConvertDependencysList(fields.Dependencys)
  end

	if(fields.OptionalDependencys) then
    self.OptionalDependencys = self:ConvertDependencysList(fields.OptionalDependencys)
  end

	return self:ValidateModinfo()
end

local StackTrace

local function SetStackTrace(err) 
	StackTrace = err..debug.traceback()
end

function ModEntry:CanLoad(vm)
  return (self.LoadState >= 0 and self.Modinfo.CanLateLoad)
end

function ModEntry:ModHasFunction(functionName)
  return self.ModTable[functionName] ~= nil
end

function ModEntry:CallModFunction(functionName, ...)

  local Function = self.ModTable[functionName]

  if(Function) then
   local success, retvalue = xpcall2(Function, PrintStackTrace, self.ModTable, ...)
   
   return success, retvalue
  end
  
  return nil
end

function ModEntry:CanLoadInVm(vm)
	local validVM = self.Modinfo.ValidVM:lower()

	return validVM == "both" or validVM == vm
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
	Description = "string",
	CanLateLoad = "boolean",
	MountSource = "boolean",
}

function ModEntry:ValidateModinfo() 
	
	local fieldlist = self.Modinfo
	
	local valid = true
	local LoadError

	for fieldName,fieldType in pairs(RequiredFieldList) do
		
		if(not fieldlist[fieldName]) then
			self:PrintError(self.Name.."'s modinfo lua file is missing required field "..fieldName)
			
			LoadError = LoadError or LoadState.ModinfoFieldMissing
		else	
		
			if(fieldType) then
				if(type(fieldlist[fieldName]) ~= fieldType) then
					self:PrintError("%s's modinfo %s field is the wrong type(%s) it should be a %s", self.Name, fieldName, type(fieldlist[fieldName]), fieldType)

					LoadError = LoadError or LoadState.ModinfoFieldInvalid
				end
			end

		end
	end

	for fieldName,fieldType in pairs(OptionalFieldList) do
		if(fieldlist[fieldName]) then		
			if(type(fieldlist[fieldName]) ~= fieldType) then
				Print("Ignoring %s's modinfo field %s  because it is the wrong type(%s) it should be a %s", self.Name, fieldName, type(fieldlist[fieldName]), fieldType)
				
				fieldlist[fieldName] = nil
			end
		end
	end

	local value = type(fieldlist.ValidVM) == "string" and fieldlist.ValidVM:lower()

	if(value and (value == "client" or value == "server" or value == "both")) then			
		self.ValidVm = value
	else
		self:PrintError("%s's modinfo ValidVM field needs tobe either \"client\", \"server\" or \"both\"", self.Name)
		LoadError = LoadError or LoadState.ModinfoFieldInvalid
	end

  if(not LoadError) then  
    if(_G[fieldlist.ModTableName]) then
      self:PrintError("%s's modinfo specifed a mod table name of %s but there is already a table named that in the global table", self.Name, fieldlist.ModTableName)
      LoadError = LoadError or LoadState.ModTableNameInUse
    end

    if(not fieldlist.ScriptList and not fieldlist.MainScript) then
      self:PrintError("%s's modinfo did not specife any lua scripts to load", self.Name)
    end
  end
  
  self.LoadState = LoadError or self.LoadState

	return LoadError == nil
end

function ModEntry:Load()
	
	if(self.ModTable) then
	  return true
	end
	
	local fields = self.Modinfo
	
	if(_G[fields.ModTableName]) then
    self:PrintError("%s's modinfo specifed a mod table name of %s but there is already a table named that in the global table", self.Name, fieldlist.ModTableName)
    self.LoadState = LoadState.ModTableNameInUse
   return false
  end

	if(fields.ScriptOverrides) then
		for replacing,replacer in pairs(fields.ScriptOverrides) do
			if(type(replacing) == "string") then
				--default to the same path as the replacing file if theres just a placeholder bool
				replacer = (type(replacer) == "string" and replacer) or replacing
				
				if(self.GameFileSystemPath) then
					xpcall2(LoadTracker.SetFileOverride, Shared.Message, LoadTracker, replacing, JoinPaths(self.GameFileSystemPath, replacer))
				else
					xpcall2(LoadTracker.SetFileOverride, Shared.Message, LoadTracker, replacing, JoinPaths(self.Path, replacer), self.FileSource)
				end
			else
				Print("Skipping entry that is a not a string in ScriptOverrides table of %s modinfo", self.Name)
			end
		end
	end

  if(fields.MountSource) then
    if(self.GameFileSystemPath) then
      NS2_IO.MountSource(self.FileSource:CreateChildSource(self.GameFileSystemPath))
    else
      NS2_IO.MountSource(self.FileSource)
    end
  end

  local mainScript = fields.MainScript and fields.MainScript:lower()
  local mainScriptResult = nil

  if(fields.ScriptList) then
	  for _,filepath in ipairs(fields.ScriptList) do
	  	if(type(filepath) == "string") then
	  	  
	  	  if(mainScript and #mainScript == #filepath and mainScript == filepath:lower()) then
	  	    --we found the main script listed in the scriptlist so load it now
	  	    mainScriptResult = self:LoadMainScript()
	  	  else
	  	    self:RunLuaFile(filepath)
	  	  end
	  	else
	  		Print("Skipping entry that is a not a string in ScriptList table of %s modinfo", self.Name)
	  	end
	  end
	end

  //if there was no ScriptList or the MainScript wasn't found in ScriptList we the run the MainScript/main loading phase now
	if(mainScriptResult == nil) then
		if(mainScript) then
		  return self:LoadMainScript()
		else
		  return self:MainLoadPhase()
		end
	end

	return mainScriptResult
end

function ModEntry:RunLuaFile(path)
	
	if(self.GameFileSystemPath) then
		--just use script load for mods that can be accessed with the games own file system so they can be hot reloaded
		return Script.Load(JoinPaths(self.GameFileSystemPath,path))
	end

	return not RunScriptFromSource(self.FileSource, JoinPaths(self.Path, path))
end

function ModEntry:LoadMainScript()
	local fields = self.Modinfo

  local MainScript = self.Modinfo.MainScript
  local MainScriptFile = JoinPaths(self.Path, MainScript)

  if(not self.FileSource:FileExists(MainScriptFile)) then
    self:PrintError("Error %s's mod entry point file does not exist", self.Name)
   return false
  end

	local ChunkOrError = self.FileSource:LoadLuaFile(MainScriptFile)

	if(type(ChunkOrError) == "string") then
		self:PrintError("Error while parsing the main script of mod %s:%s", self.Name, ChunkOrError)
	 return false
	end

	--just run it in the global enviroment
	local success = xpcall(ChunkOrError, SetStackTrace)

	if(not success) then
		self:PrintError("Error while running the main script of mod %s :%s", self.Name, StackTrace)
	 return false
	end
	
	if(self.GameFileSystemPath) then
	 local path = NormalizePath(JoinPaths(self.GameFileSystemPath, MainScript))
		--mark it for hotreloading
		Script.includes[path] = true
	end
	
	return self:MainLoadPhase()
end

function ModEntry:ModHasFunction(funcName)
  return self.ModTable[funcName] ~= nil
end

function ModEntry:InjectFunctions()
  
  local ModTable = self.ModTable
  
  ModTable.LoadScript = function(selfArg, path) 
		self:RunLuaFile(path)
	end
	
	ModTable.HookFileLoadFinished = function(selfArg, scriptPath, func)
	  return LoadTracker:HookFileLoadFinished(scriptPath, selfArg, func)
	end

  ModTable.LoadScriptAfter = function(selfArg, scriptPath, afterScriptPath) 
    replacer = (type(replacer) == "string" and replacer) or replacing
				
		if(self.GameFileSystemPath) then
	    LoadTracker:LoadScriptAfter(scriptPath, JoinPaths(self.GameFileSystemPath, afterScriptPath))
		else
			LoadTracker:LoadScriptAfter(scriptPath, JoinPaths(self.Path, afterScriptPath), self.FileSource)
		end
	end

  if(NS2_IO and not self.IsArchive) then	
	  ModTable.LoadLuaDllModule = function(selfArg, path) 
	  	return NS2_IO.LoadLuaDllModule(self.FileSource, JoinPaths(self.Path, path))
	  end
	end
end

function ModEntry:MainLoadPhase()
  
  local fields = self.Modinfo
	local ModTable = _G[fields.ModTableName]

	if(not ModTable) then
	  self.LoadState = LoadState.ModTableMissing
	  
		self:PrintError(self.Name.." modtable could not be found after loading")
	 return false
	end
	
	self.ModTable = ModTable
	
	self:InjectFunctions()
	
	--should add a way to have saved vars for client VM only or Server Vm only
	--so both vms aren't writing to the same file when were running in a listen server
	if(fields.SavedVaribles) then
		local sucess, sv = pcall(SavedVariables, self.Name, fields.SavedVaribles, ModTable)
		
		if(sucess) then
			self.SavedVars = sv
			self.SavedVars:Load()
		else
			Print("Error while setting up saved varibles for mod %s: %s", self.Name, sv)
		end
	end
	
	self:CallModFunction("OnLoad")
	
	self.IsLoaded = true
  
  return true
end

function ModEntry:OnDependencyMissing(modname)
  self:PrintError("Cannot load mod %s because its missing dependency %s", self.Name, modname)

  if(self.LoadState >= 0) then
    self.LoadState = LoadState.DependencyMissing
  end
end

function ModEntry:OnDependencyLoadError(modname)

  if(self.LoadState >= 0) then
    self.LoadState = LoadState.DependencyHasError
    
    self:PrintError("Cannot load mod %s because its dependency \'%s\' had errors while starting up", self.Name, modname)
  end
end

function ModEntry:PrintError(...)
  --TODO add recording of these errors
  Print(...)
end

function ModEntry:OnClientLuaFinished()

	if(not self.IsLoaded) then
		return
	end

	self:CallModFunction("OnClientLuaFinished")
	self:CallModFunction("OnSharedLuaFinished")
end

function ModEntry:OnServerLuaFinished()

	if(not self.IsLoaded) then
		return
	end

	self:CallModFunction("OnServerLuaFinished")
	self:CallModFunction("OnSharedLuaFinished")
end

function ModEntry:CanDisable()

	local success,ret = self:CallModFunction("CanDisable")
	
	return (success and ret) or false
end


function ModEntry:Enable()
end

function ModEntry:Disable()
  
  if(not self:CanDisable()) then
    error(self.Name.." cannot be runtime disabled")
  end
  
  self:CallModFunction("Disable")
end