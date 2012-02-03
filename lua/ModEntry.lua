//
//   Created by:   fsfod
//

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
	MainScriptMissing   = -9,
	MainScriptLoadError = -10,
	MainScriptRunError  = -11,
	ModTableMissing     = -12,

	Disabled = 0,
	ModinfoLoaded = 1,
	FullyLoaded = 2,
	LoadedAndDisabled = 3,
}

local EntryMetaTable = {
	__index = ModEntry,
}

local IsRootFileSource = NS2_IO and NS2_IO.IsRootFileSource


function CreateModEntry(Source, dirname, IsArchive, pathInSource)
	
	local ModData = {
		FileSource = Source, 
		Name = dirname,
		InternalName = dirname:lower(),
		IsArchive = IsArchive,
		LoadState = 0,
	}

	local IsFromRootSource = IsRootFileSource and IsRootFileSource(Source)

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

local lowerCache = setmetatable({}, {__mode = "k"})

local ChangeCaseMT = {
  __newindex = function(tbl, key, value)   
    local lkey = lowerCache[key]
    
    if(not lkey) then
      lkey = key:lower()
      lowerCache[key] = lkey
    end
    
    rawset(tbl, lkey, value) 
  end,
 
  __index = function(tbl, key) 
   local lkey = lowerCache[key]
    
    if(not lkey) then
      lkey = key:lower()
      lowerCache[key] = lkey
    end
    
    return rawget(tbl, lkey) 
  end,
}

ModEntry.ChangeCaseMT = ChangeCaseMT

function ModEntry:ConvertDependenciesList(list)

  local deps = {}

  for _,name in ipairs(list) do
    if(type(name) == "string" and name ~= "") then
      deps[name:lower()] = true
    end
  end
  
  return next(deps) and deps
end

function ModEntry:LoadModinfo()

  if(self.Modinfo) then
    return true
  end

	local Source = self.FileSource
  local success, chunk, errorMsg

	if(Source) then
    success, chunk, errorMsg = pcall(Source.LoadLuaFile, Source, self.Path.."modinfo.lua")
    
    //if LoadLuaFile threw an error the second return value from pcall will be the error 
    if(not success) then
      errorMsg = chunk
    end 
  elseif(__ModPath) then
    chunk, errorMsg = loadfile(string.format("%s/modinfo.lua", JoinPaths(__ModPath, self.GameFileSystemPath)))
  end

	if(success == false) then
	  self.LoadState = LoadState.ModinfoLoadError
		self:PrintError("error while trying to read %s's modinfo file:\n%s", self.Name, errorMsg)
	 return false
	end

	if(errorMsg) then
	  self.LoadState = LoadState.ModinfoParseError

		self:PrintError("error while parsing %s's modinfo file:\n%s", self.Name, errorMsg)
	 return false
	end
		
	local fields = setmetatable({}, ChangeCaseMT)
		setfenv(chunk, fields)

	local success, msg = pcall(chunk)
		 
	if(not success) then
	  self.LoadState = LoadState.ModinfoRunError
		self:PrintError("error while running %s's modinfo file:\n%s", self.Name, msg)	
		
		return false
	end

  return self:ProcessModInfo(fields)
end

function ModEntry:ProcessModInfo(fields)
	self.Modinfo = fields

	self.Valid = true

	if(fields.Dependencies) then
    self.Dependencies = self:ConvertDependenciesList(fields.Dependencies)
  end

	if(fields.OptionalDependencies) then
    self.OptionalDependencies = self:ConvertDependenciesList(fields.OptionalDependencies)
  end

  self.LoadState = LoadState.ModinfoLoaded

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
	local validVM = self.Modinfo.ValidVM


  if(type(validVM) == "table") then
    return validVM[vm] == true
  else
    return validVM == vm
  end
end

local RequiredFieldList ={
	ValidVM = false,
	EngineBuild = "number",
	ModTableName = "string",
}

local OptionalFieldList = {
	SavedVaribles = "table",
	Dependencies = "table",
	MainScript = "string",
	ScriptList = "table",
	ScriptOverrides = "table",
	Description = "string",
	CanLateLoad = "boolean",
	MountSource = "boolean",
	DLLModules = "table",
	RequiresLuabind = "boolean",
}

local VMList = {
  client = "client",
  server = "server",
  main = "main",

  all = {
    main = true,
    client = true,
    server = true,
  },

  clientserver = {
    client = true,
    server = true,
  },
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
				RawPrint("Ignoring %s's modinfo field %s  because it is the wrong type(%s) it should be a %s", self.Name, fieldName, type(fieldlist[fieldName]), fieldType)
				
				fieldlist[fieldName] = nil
			end
		end
	end

	local vmName = type(fieldlist.ValidVM) == "string" and VMList[fieldlist.ValidVM:lower()]

	if(vmName) then	
 		
		self.ValidVm = VMList[vmName]

	elseif(type(fieldlist.ValidVM) == "table") then

	  self.ValidVm = setmetatable(fieldlist.ValidVM, ChangeCaseMT)

	else
		self:PrintError("%s's modinfo ValidVM field needs tobe either \"client\", \"server\" or \"main\" or a table with one of these values", self.Name)
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
	
	if(fields.RequiresLuabind) then
	
	  if(not ModuleBootstrap or not ModuleBootstrap:TryLoadLuabind()) then
	    self.LoadState = LoadState.DependencyMissing
	    
	    self:PrintError("%s mod requires luabind but luabind is missing or failed to load", self.Name)
	    
	    return false
	  end
	end
	
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
				RawPrint("Skipping entry that is a not a string in ScriptOverrides table of %s modinfo", self.Name)
			end
		end
	end

  if(fields.MountSource and NS2_IO) then
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
	  		RawPrint("Skipping entry that is a not a string in ScriptList table of %s modinfo", self.Name)
	  	end
	  end
	end

  //if there was no ScriptList or the MainScript wasn't found in ScriptList we the run the MainScript/main loading phase now
	if(mainScriptResult == nil) then
		if(mainScript) then
		  mainScriptResult = self:LoadMainScript()
		else
		  mainScriptResult =  self:MainLoadPhase()
		end
	end

  if(self.LoadState > 0) then
    self.LoadState = LoadState.FullyLoaded
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
  local MainScript = self.Modinfo.MainScript
  local ChunkOrError

  if(self.FileSource) then
    local MainScriptFile = JoinPaths(self.Path, MainScript)

    if(not self.FileSource:FileExists(MainScriptFile)) then
      self:PrintError("Error %s's MainScript file does not exist", self.Name)
      self.LoadState = LoadState.MainScriptMissing
     return false
    end
    
    ChunkOrError = self.FileSource:LoadLuaFile(MainScriptFile)
  elseif(__ModPath) then
    local errorMsg
    
    local scriptPath = __ModPath..JoinPaths(self.GameFileSystemPath, MainScript)
    
    ChunkOrError, errorMsg = loadfile(scriptPath)
    
    --loadfile returns the function first and the error second. nil function = error set
    if(not ChunkOrError) then
      chunkOrError = errorMsg
    else
      Script.includes[string.lower(scriptPath)] = true
    end
  else
    assert(false, "no way to load MainScript")
  end

	if(type(ChunkOrError) == "string") then
		self:PrintError("Error while loading the main script of mod %s:%s", self.Name, ChunkOrError)
		self.LoadState = LoadState.MainScriptLoadError
	 return false
	end

	--just run it in the global enviroment
	local success = xpcall(ChunkOrError, SetStackTrace)

	if(not success) then
		self:PrintError("Error while running the main script of mod %s :%s", self.Name, StackTrace)
		self.LoadState = LoadState.MainScriptRunError
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
    afterScriptPath = (type(afterScriptPath) == "string" and afterScriptPath) or scriptPath
				
		if(self.GameFileSystemPath) then
	    LoadTracker:LoadScriptAfter(scriptPath, JoinPaths(self.GameFileSystemPath, afterScriptPath))
		else
			LoadTracker:LoadScriptAfter(scriptPath, JoinPaths(self.Path, afterScriptPath), self.FileSource)
		end
	end
	
  if(__ModPath or (NS2_IO and not self.IsArchive)) then	
	  ModTable.LoadLuaDllModule = function(selfArg, path) 
	    return self:LoadLuaDllModule(path)
	  end
	  
	  ModTable.RunLuaDllModule = function(selfArg, path)
	    local entrypoint, msg, where = self:LoadLuaDllModule(path)
    
	    if(not entrypoint) then
	      error(string.format("Error while Loading %s lua dll module:%s", path, msg))
	    end
    
	    return entrypoint()
    end
	end
end

if(NS2_IO) then
  
  function ModEntry:LoadLuaDllModule(path)
    return NS2_IO.LoadLuaDllModule(self.FileSource, JoinPaths(self.Path, path))
  end
else
  
  function ModEntry:LoadLuaDllModule(path)
  
    local fullPath = JoinPaths(JoinPaths(__ModPath, self.GameFileSystemPath), path)
    
    local funcName = GetFileNameWithoutExt(path)
    
    Shared.Message("Loading lua dll module "..path)
    
    if(funcName) then
      funcName = "luaopen_"..funcName
    end
    
    return package.loadlib(fullPath, funcName)
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
			RawPrint("Error while setting up saved varibles for mod %s: %s", self.Name, sv)
		end
	end
	
	self:CallModFunction("OnLoad")
	  
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
  RawPrint(...)
end

function ModEntry:OnClientLuaFinished()

	if(not self:IsActive()) then
		return
	end

	self:CallModFunction("OnClientLuaFinished")
	self:CallModFunction("OnSharedLuaFinished")
end

function ModEntry:OnServerLuaFinished()

	if(not self:IsActive()) then
		return
	end

	self:CallModFunction("OnServerLuaFinished")
	self:CallModFunction("OnSharedLuaFinished")
end

function ModEntry:CanDisable()

	local success,ret = self:CallModFunction("CanDisable")
	
	return (success and ret) or false
end

function ModEntry:HasStartupErrors()
  return self.LoadState < 0
end

function ModEntry:IsLoaded()
  return self.LoadState >= LoadState.FullyLoaded
end

function ModEntry:IsActive()
  return self.LoadState == LoadState.FullyLoaded
end

function ModEntry:Enable()
end

function ModEntry:Disable()

  if(self.LoadState <= LoadState.ModinfoLoaded or self.LoadState == LoadState.LoadedAndDisabled) then
    --just do nothing since we either had fatal errors or we've only loaded the modinfo
    return
  end

  if(not self:CanDisable()) then
    error(self.Name.." cannot be runtime disabled")
  end

  self:CallModFunction("Disable")
 
  self.LoadState = LoadState.LoadedAndDisabled
end