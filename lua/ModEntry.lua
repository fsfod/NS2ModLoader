ModEntry = {}

LoadState = enum{
	MissingModinfoFile,
	FailedToParseModinfo,
	ErrorWhileLoading
}

local EntryMetaTable = {
	__index = ModEntry,
}

local IsRootFileSource = NS2_IO.IsRootFileSource

local function PrintStackTrace(err) 
	Shared.Message(debug.traceback(err, 1))
end

function CreateModEntry(Source, dirname, IsArchive, pathInSource)
	
	local ModData = {
		FileSource = Source, 
		Name = dirname,
		InternalName = dirname:lower(),
		IsArchive = IsArchive,
	}

	local IsFromRootSource = IsRootFileSource(Source)

	if(IsFromRootSource) then
		ModData.GameFileSystemPath = "Mods/"..dirname
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

function ModEntry:LoadModinfo()
	
	self.Valid = false

	local Source = self.FileSource
	local success, chunkOrError = pcall(Source.LoadLuaFile, Source, self.Path.."modinfo.lua")

	if(not success) then
		Print("error while trying to read %s's modinfo file:\n%s", self.Name, chunkOrError)
	 return false
	end

	if(type(chunkOrError) == "string") then
		Print("error while parsing %s's modinfo file:\n%s", self.Name, chunkOrError)
	 return false
	end
		
	local fields = setmetatable({}, ChangeCaseMT)
		setfenv(chunkOrError, fields)

	local success, msg = pcall(chunkOrError)
		 
	if(not success) then
			Print("error while running %s's modinfo file:\n%s", self.Name, msg)	
		return false
	end

	self.Modinfo = fields

	self.Valid = true

	if(fields.Dependencys) then
    local deps = {}

    for _,name in ipairs(fields.Dependencys) do
      if(type(name) == "string" and name ~= "") then
        deps[name:lower()] = true
      end
    end

    if(next(deps)) then
      self.Dependencys = deps
    end
  end
	
	return self:ValidateModinfo()
end

local StackTrace

local function SetStackTrace(err) 
	StackTrace = err..debug.traceback()
end

function ModEntry:CanLoad(vm)
  return (self.Valid and self.Modinfo.CanLateLoad)
end

function ModEntry:ModHasFunction(functionName)
  return self.ModTable[functionName] ~= nil
end

function ModEntry:CallModFunction(functionName, ...)

  local Function = self.ModTable[functionName]

  if(Function) then
   local success, retvalue = xpcall(Function, PrintStackTrace, self.ModTable, ...)
   
   return success, retvalue
  end
  
  return nil
end

function ModEntry:CanLoadInVm(vm)
	local validVM = self.Modinfo.ValidVM:lower()

	return validVM == "both" or validVM == vm
end

local RequiredFieldList ={
	EntryPointFile = "string",
	ValidVM = false,
	EngineBuild = "number"
}

local OptionalFieldList = {
	SavedVaribles = "table",
	ExtraFiles = "table",
	OverrideFiles = "table",
	ModTableName = "string",
	CanLateLoad = "boolean"
}

function ModEntry:ValidateModinfo() 
	
	local fieldlist = self.Modinfo
	
	local valid = true
	
	for fieldName,fieldType in pairs(RequiredFieldList) do
		
		if(not fieldlist[fieldName]) then
			Shared.Message(self.Name.."'s modinfo lua file is missing required field "..fieldName)
			valid = false
		else			
			if(fieldType) then
				if(type(fieldlist[fieldName]) ~= fieldType) then
					Print("%s's modinfo %s field is the wrong type(%s) it should be a %s", self.Name, fieldName, type(fieldlist[fieldName]), fieldType)
				
					valid = false
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
	
	if(valid) then
		--ModTableName defaults to the name of the entry point file with the extension striped off
		if(not fieldlist.ModTableName) then
			fieldlist.ModTableName = StripExtension(fieldlist.EntryPointFile)
		end
	end
	
	local value = type(fieldlist.ValidVM) == "string" and fieldlist.ValidVM:lower()
	
	if(value and (value == "client" or value == "server" or value == "both")) then			
		self.ValidVm = value
	else
		Print("%s's modinfo ValidVM field needs tobe either \"client\", \"server\" or \"both\"", self.Name)
		valid = false
	end

  self.Valid = valid

	return valid
end

function ModEntry:Load()
	
	if(not self.ModTable) then
		local fields = self.Modinfo

			if(fields.ExtraFiles) then
				for _,filepath in ipairs(fields.ExtraFiles) do
					if(type(filepath) == "string") then
						self:RunLuaFile(filepath)
					else
						Print("Skipping entry that is a not a string in ExtraFiles table of %s modinfo", self.Name)
					end
				end
			end

		if(fields.OverrideFiles) then
			for replacing,replacer in pairs(fields.OverrideFiles) do
				if(type(replacing) == "string") then
					
					replacer = (type(replacer) == "string" and replacer) or replacing
					
					if(self.GameFileSystemPath) then
						xpcall(LoadTracker.SetFileOverride, Shared.Message, LoadTracker, replacing, JoinPaths(self.GameFileSystemPath, replacing))
					else
						xpcall(LoadTracker.SetFileOverride, Shared.Message, LoadTracker, replacing, JoinPaths(self.Path, replacer), self.FileSource)
					end
				else
					Print("Skipping entry that is a not a string in OverrideFiles table of %s modinfo", self.Name)
				end
			end
		end
		
		return (xpcall(self.LoadEntryPointFile, Shared.Message, self))
	end
	
	return true
end

function ModEntry:RunLuaFile(path)
	
	if(self.GameFileSystemPath) then
		--just use script load for mods that can be accessed with the games own file system so they can be hot reloaded
		return Script.Load(JoinPaths(self.GameFileSystemPath,path))
	end

	return not RunScriptFromSource(self.FileSource, JoinPaths(self.Path, path))
end

function ModEntry:LoadEntryPointFile()
	local fields = self.Modinfo

  local EntryPointFile = JoinPaths(self.Path,fields.EntryPointFile)

  if(not self.FileSource:FileExists(EntryPointFile)) then
    Print("Error %s's mod entry point file does not exist", self.Name)
   return false
  end

	local ChunkOrError = self.FileSource:LoadLuaFile(JoinPaths(self.Path,fields.EntryPointFile))

	if(type(ChunkOrError) == "string") then
		Print("Error while parsing entry point file for %s:%s", self.Name, ChunkOrError)
	 return false
	end

	--just run it in the global enviroment
	local success = xpcall(ChunkOrError, SetStackTrace)

	if(not success) then
		Print("Error while running entry point of mod %s :%s", self.Name, StackTrace)
	 return false
	end
	
	local ModTable = _G[fields.ModTableName]

	if(not ModTable) then
		Print(self.Name.." modtable could not be found after loading")
	 return false
	end
	
	if(self.GameFileSystemPath) then
	 local path = NormalizePath(JoinPaths(self.GameFileSystemPath, fields.EntryPointFile))
		--mark it for hotreloading
		Script.includes[path] = true
	end
	
	self.ModTable = ModTable
	
	ModTable.LoadScript = function(selfArg, path) 
		self:RunLuaFile(path)
	end

  if(not self.IsArchive) then	
	  ModTable.LoadLuaDllModule = function(selfArg, path) 
	  	return NS2_IO.LoadLuaDllModule(self.FileSource, JoinPaths(self.Path, path))
	  end
	end
	
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
