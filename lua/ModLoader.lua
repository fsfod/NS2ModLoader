//
//   Created by:   fsfod
//

/*
Notes 

Mods are kept in an load ordered list each event is dispatched to mods in the same order of the list

Mods with no dependencies are first sorted by name then loaded in that order this is more for conistentcy than tobe used by mods

*/

local HotReload = false

local Mods, ActiveMods, OrderedActiveMods

if(not ModLoader) then
	ModLoader = {
		DisabledMods = {},
		OrderedActiveMods = {},
		ActiveMods = {},
		Mods = {},

    //A true value means load the mod even if its set to disabled 
    //A false value means don't load the mod even its enable
    //if the entry for the mod is nil in the table then just use the value in DisabledMods
		ModLoadOverrides = {},
	}
	
	//ActiveMods = {}
	
	//ModLoader.Mods = Mods
	//ModLoader.ActiveMods = ActiveMods
else
  HotReload = true 
  //Mods = ModLoader.Mods
  //ActiveMods = ModLoader.ActiveMods
end

ClassHooker:Mixin("ModLoader")

local VMName = decoda_name:lower()
local OppositeVMName = (Server and "Client") or "Server"


function ModLoader:Init()  
  self:SetupConsoleCommands()
  
  if(not StartupLoader.ReloadInprogress) then
  
    if(SavedVariables) then
      self.SV = SavedVariables("ModLoader", {"DisabledMods"}, self)
    
	    self.SV:Load()
	    
	    if(Server) then
	       self.SV.AutoSave = false
	    end
    end
    
    if(self.Embeded) then
      if(self.EmbededMods) then
        
	      for _,mod in ipairs(self.EmbededMods) do
          self:AddModFromDir(unpack(mod))
        end
      end
	  end
	
	  self:ScannForMods()
	  self:LoadMods()
	else
	  self:ReloadLuaFiles()
  end
  
	self:SetHooks()
end

function ModLoader:ReloadLuaFiles()

  for _,mod in ipairs(self.OrderedActiveMods) do
    mod:ReloadLuaFiles()
  end
end

function ModLoader:SetEmbededMods(modsList)
  
  assert(type(modsList) == "table")
  
  self.Embeded = true
  
  self.EmbededMods = modsList
end

function ModLoader:SetupConsoleCommands()

  if(Client) then
		Event.Hook("Console_enablemod", function(modName) self:EnableMod(modName) end)
		Event.Hook("Console_disablemod", function(modName) self:DisableMod(modName) end)
		Event.Hook("Console_enableallmods", function() self:EnableAllMods() end) 
		Event.Hook("Console_disableallmods", function() self:DisableAllMods() end) 
		Event.Hook("Console_listmods", function() self:ListMods() end)
	end

	if(not self.Embeded) then
	  if(Client) then
		  Event.Hook("Console_ML_ResponseSV", function() Print("Recv mod list") end)
		
		  Event.Hook("Console_ML_RequestCL", function() 
		    self:SendModListResponse() 
		    Shared.ConsoleCommand("ML_RequestSV")
		  
		  end)
	  else
	    Event.Hook("Console_ML_RequestSV", function(client) self:SendModListResponse(client:GetControllingPlayer()) end)
	    Event.Hook("Console_ML_ResponseCL", function(client, ...) self:HandleModListResponse(client, ...) end)
	  end
	end

end

function ModLoader:SetHooks()

  if(Server and not self.Embeded) then
    self:PostHookClassFunction("Gamerules", "OnClientConnect")
  end
end

function ModLoader:OnClientConnect(selfobj, client)
 
  local ent = client:GetControllingPlayer()

  client.ModRequestSent = Shared.GetTime()
	self:RequestModList(ent)

  self:DispatchModCallback("OnClientConnect", client, ent)
end

function ModLoader:DispatchModCallback(functionName, ...)
  for _,mod in ipairs(self.OrderedActiveMods) do
    mod:CallModFunction(functionName, ...)
  end
end

function ModLoader:HandleModListResponse(client, ...)

  --just incase any mods had spaces in there names
  local listString = table.concat({...}, "")

  RawPrint("HandleModListResponse %s", listString)

  local list = {}

  string.gsub(listString, "([^:]+)", function(s) list[s] = true end)
  
  client.ModList = list

  for modName,_ in pairs(list) do
   local mod = self.Mods[modName]
   
    if(mod) then
     if(Server) then
       mod:CallModFunction("ClientHasMod", client)
     else
       mod:CallModFunction("ServerHasMod", client)
     end
    end
  end
end

function ModLoader:RequestModList(client)

  RawPrint("RequestModList")

  local ConsoleCmd = (Server and "ML_RequestCL") or "ML_RequestSV"
  
  if(Server) then
    Server.SendCommand(client, ConsoleCmd)
  else
    Shared.ConsoleCommand(ConsoleCmd)
  end
end

function ModLoader:SendModListResponse(client)
  
  local modlist = table.concat(self:GetListOfActiveMods(), ":")
  
  RawPrint("SendModListResponse "..modlist)
  
  local ConsoleCmd = (Server and "ML_ResponseSV ") or "ML_ResponseCL "
  
  ConsoleCmd = ConsoleCmd..modlist
  
  
  if(client) then
    Server.ClientCommand(client, ConsoleCmd)
  else
    Shared.ConsoleCommand(ConsoleCmd)
  end
end

function ModLoader:GetListOfActiveMods()
  
  local list = {}

  for name,mod in pairs(self.OrderedActiveMods) do
    list[#list+1] = name
  end

  return list
end

function ModLoader:IsModEnabled(modName)
  return not self:_IsModDisabled(modName:lower())
end

function ModLoader:_IsModDisabled(modName)
  
  if(self.ModLoadOverrides[modName] ~= nil) then
    return not self.ModLoadOverrides[modName]
  end
  
  return self.DisabledMods[modName] == true
end

function ModLoader:IsModActive(name)
  
  name = name:lower()
  
  for modName,mod in pairs(self.OrderedActiveMods) do
    if(modName == name) then
      return true
    end
  end
  
  return false
end

function ModLoader:GetModInfo(name)
  
  local modentry = self.Mods[name]
  
  return self:_IsModDisabled(name), modentry.Name, modentry.LoadState
end

function ModLoader:GetModList(justOptional)
  
  local list = {}

  for name,mod in pairs(self.Mods) do
    if(not justOptional or not mod.Required) then
      list[#list+1] = name
    end
  end

  return list
end

function ModLoader:ListMods()
  
	for name,mod in pairs(self.Mods) do
		if(mod:HasStartupErrors()) then
	    RawPrint("%s : Enabled but encountered fatal error while loading", name)
		elseif(self:_IsModDisabled(name)) then
			RawPrint("%s : Disabled%s", name, (mod:IsLoaded() and " but still loaded this session") or "")
		else
			RawPrint("%s : Enabled", name)
		end
	end
end

function ModLoader:EnableAllMods()
	
	for name,mod in pairs(self.Mods) do
		if(not mod.Required and self.DisabledMods[name]) then
			self:EnableMod(name)
		end
	end
end

function ModLoader:DisableAllMods()
	
	for name,mod in pairs(self.Mods) do
		if(not self.DisabledMods[name] and not mod.Required) then
			self:DisableMod(name)
		end
	end
end

function ModLoader:ModEnableStateChanged(name)
  
  if(self.SV) then
    self.SV:Save()
  else
    Client.SetOptionBoolean("ModLoader/Disabled/"..name, self.DisabledMods[name])
  end
end

function ModLoader:EnableMod(modName)
	
	if(not modName) then
		RawPrint("EnableMod: Need to specify the name of a mod to enable")
	 return false
	end
	
	local name = modName:lower()
	
	if(not self.Mods[name]) then
		RawPrint("EnableMod: No mod named "..modName.." installed")
	 return false
	end

	self.DisabledMods[name] = false
	
	self:ModEnableStateChanged(name)
	
	RawPrint("Mod %s set to enabled a restart is require for this mod tobe loaded", modName)
	
	return true
end

function ModLoader:DisableMod(modName)
	
	if(not modName) then
		RawPrint("DisableMod: Need to specify the name of a mod to disable")
	 return false
	end
	
	local name = modName:lower()
	local mod = self.Mods[name]
	
	if(not mod) then
		RawPrint("DisableMod: No mod named "..modName.." installed")
	 return false
	end
	
	if(mod.Required) then
	   RawPrint("DisableMod: Cannot disable required mod "..modName)
	  return false
	end
	
	self.DisabledMods[name] = true

	if(mod:IsActive()) then	  
	  if(mod:CanDisable()) then
	    mod:Disable()
	    RawPrint("DisableMod: Mod %s has been set to disabled and has activly disabled its self", modName)
	  else
	    RawPrint("DisableMod: Mod %s set to disabled this mod will still be loaded for this session", modName)
	  end
	else
		RawPrint("DisableMod: Mod %s set to disabled", modName)
	end
	
	self:ModEnableStateChanged(name)
	
	return true
end

function ModLoader:ScannForMods()

  if(not NS2_IO) then
    self:ScannForMods_Basic()
   return
  end
  
	for dirname,Source in pairs(NS2_IO.FindDirectorys("/Mods/","")) do
 		
		local modinfopath = string.format("/Mods/%s/modinfo.lua", dirname)
		
		if(not Source:FileExists(modinfopath)) then
			RawPrint("Skiping mod directory \"%s\" that has no modinfo.lua in it", dirname)
		else
		  self:AddModEntry(Source, dirname)
		end
	end
	
	local SupportedArchives = NS2_IO.GetSupportedArchiveFormats()
	
	--scan for mods are contained in archives that are in our "Mods" folder
	for fileName,Source in pairs(NS2_IO.FindFiles("/Mods/","")) do
	
		if(SupportedArchives[(GetExtension(fileName) or ""):lower()]) then
			local success, archiveOrError = pcall(NS2_IO.OpenArchive, Source, "/Mods/"..fileName)
	
			if(success) then
				self:TryAddArchiveMod(archiveOrError, fileName)
			else
				RawPrint("error while opening mod archive %s :\n%s", fileName, archiveOrError)
			end
		end
		
	end
end

function ModLoader:TryAddArchiveMod(archive, fileName)
  
  if(archive:FileExists("modinfo.lua")) then
		self:AddModEntry(archive, StripExtension(fileName), true)
	else
	  local dirlist = archive:FindDirectorys("", "")
	  local modname = dirlist[1]
	  --if theres no modinfo.lua in the root of the archive see if the archive contains a single directory that has a modinfo.lua in it
	  if(#dirlist == 1 and archive:FileExists(modname.."/modinfo.lua")) then
	    self:AddModEntry(archive, modname, true, modname.."/")
	  else
	    RawPrint("Skiping mod archive \"%s\" that has no modinfo.lua in it", fileName)
	  end
	end
end

function ModLoader:ScannForMods_Basic()
  
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
			  self:TryAddArchiveMod(archiveOrError, fileName)
			else
				RawPrint("error while opening mod archive %s :\n%s", fileName, archiveOrError)
			end
		end
	end
	
end

function ModLoader:AddModFromDir(dirPath, name, optional, defaultDisabled)
  local mod = CreateModEntry_Basic(dirPath, name)
  
  local name = mod.InternalName
    
  if(optional) then
    
    //sigh GetOption stuff really needs tobe moved to shared.  just treat server mods as always enabled 
    self.DisabledMods[name] = self.DisabledMods[name] or false//Client.GetOptionBoolean("ModLoader/Disabled/"..name, defaultDisabled)
  else
    mod.Required = true
  end
  
  self.Mods[name] = mod
end

function ModLoader:LoadModFromDir(dirPath, name, optional, defaultDisabled)
  local mod = CreateModEntry(dirPath, name)
  
  local name = mod.InternalName
    
  if(optional) then
    self.DisabledMods[name] = self.DisabledMods[name] or false
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

function ModLoader:AddModEntry(source, modname, isArchive, pathInSource)

  local normName = modname:lower()

  if(self.Mods[normName]) then
    
    local mod = self.Mods[normName]
    
    
    if(isArchive and not mod.IsArchive) then
      RawPrint("Skipping mod %s in archive because there is mod with the same name in a folder already loaded", modname)
    else
      RawPrint("Skipping mod %s because another mod with the same name has already been loaded", modname)
    end
    
   return
  end


  self.Mods[normName] = CreateModEntry(source, modname, isArchive, pathInSource)
end

function ModLoader:UILoadingStarted()
  self:DispatchModCallback("OnUILoading")
end

function ModLoader:OnClientLoadComplete(disconnectMsg)
  	  
	if(self.EmbededMods) then
	    

  end
  
  self:DispatchModCallback("OnClientLoadComplete", disconnectMsg)
end

function ModLoader:OnLuaLoadFinished()

  if(Server) then
    self:OnServerLuaFinished()
  else
    self:OnClientLuaFinished()
  end
end

function ModLoader:OnClientLuaFinished()
	self:DispatchModCallback("OnClientLuaFinished")
end

function ModLoader:OnServerLuaFinished()
	self:DispatchModCallback("OnServerLuaFinished")
end

function ModLoader:InternalLoadMod(mod)
  
  if(mod:HasStartupErrors()) then
    return false
  end
    
  RawPrint("Loading mod: "..mod.Name)

  if(not mod:Load()) then
	  return false
	end
		  
	self.OrderedActiveMods[#self.OrderedActiveMods+1] = mod

  return true
end

function ModLoader:LoadMod(modName)
  
  local name = modName:lower()
  local ModEntry = self.Mods[name]

  if(not ModEntry) then
    error("ModLoader:LoadMod No mod named "..modName)
  end
  
  if(not ModEntry:CanLoadInVm(VMName)) then
    error(string.format("LoadMod Error: Mod %s can only be loaded in the %s lua VM", modName, OppositeVMName))
  end
  
  
end

function ModLoader:SetModEnabledOverride(modname)
  self.ModLoadOverrides[modname:lower()] = true
end

function ModLoader:SetModDisabledOverride(modname)
  self.ModLoadOverrides[modname:lower()] = false
end

function ModLoader:LoadMods()

  local LoadableMods = {}
  --a hashtable The key is the name of mod. the value a keyvalue list of mods that depend on the mod
  local Dependents = {}
  local noDepList = {}

  for modname,entry in pairs(self.Mods) do
    local override = self.ModLoadOverrides[modname]
    
		if entry:LoadModinfo() and (not self.DisabledMods[modname] or override) and override ~= false and entry:CanLoadInVm(VMName) then

		  if(entry.Dependencies) then
		    local list = entry.Dependencies
		  
		    for name,_ in pairs(entry.Dependencies) do
		      Dependents[name] = (Dependents[name] or 0)+1
		      list[name] = self.Mods[name]
        end
      else
        //defer adding the mod to normal list to the OptionalDependencies loop
        noDepList[modname] = true
      end

      LoadableMods[modname] = entry
		end
	end

	for modName, modEntry in pairs(LoadableMods) do
    
    if(modEntry.OptionalDependencies) then
      local list = modEntry.Dependencies
      local addedDeps = false
      
      for name,_ in pairs(modEntry.OptionalDependencies) do
        if(LoadableMods[name]) then
          Dependents[name] = (Dependents[name] or 0)+1
          addedDeps = true

          if(not list) then
            list = {}
            modEntry.Dependencies = list
          end
          list[name] = LoadableMods[name]
        end
      end
      
      if(addedDeps) then
        noDepList[modName] = nil
      end
    end
  end
	

  local loadResult = {}

	self:SortAndLoadModList(noDepList, loadResult)

  if(next(Dependents)) then
    self:HandleModsDependencies(LoadableMods, Dependents, loadResult)
  end
end

function ModLoader:SortAndLoadModList(list, loadResult)

  local arrayList = {}
  
  for modname,_ in pairs(list) do
    arrayList[#arrayList+1] = modname
  end
  
  table.sort(arrayList)

  local ordered = self.OrderedActiveMods

  for _,modname in pairs(arrayList) do
	  loadResult[modname] = self:InternalLoadMod(self.Mods[modname]) 
  end
end

function ModLoader:ReportDependencieCycle(stack, mod)
  
  local cycleStart
  
  local modNames = {}
  
  for i, stackEntry in ipairs(stack) do
    if(stackEntry == mod and not cycleStart) then
      cycleStart = i
    end

    modNames[#modNames+1] = stackEntry.Name
  end

  local modListString = table.concat(modNames, ", ")

  RawPrint("Error cycle in mod dependencies found for %s cycle mod is %s, load stack is %s", stack[1].Name, mod.Name, modListString)
end

function ModLoader:HandleModsDependencies(LoadableMods, Dependents, loadResults)
  
  local RootList = {}

  --build up a list of root nodes for our topological sort
  --mods with dependencie cycles 
  for modname,entry in pairs(LoadableMods) do
    if not Dependents[modname] then
		  RootList[modname] = entry
		end
	end

  local stack = {}

  local LoadModDependencies
  
  //Depth First traversal topological sorter loader
  LoadModDependencies = function(mod)
    
    if(mod:IsLoaded()) then
      return true
    end
    
    stack[#stack+1] = mod
    
    //check that we havn't been to this node already otherwise we have found a dependencie cycle
    if(mod.Visited) then
      self:ReportDependencieCycle(stack, mod)
     return false
    end
    
    mod.Visited = true

    local depFailed = false
    
    if(mod.Dependencies) then
      //recurse call into our dependencies
      for name,depMod in pairs(mod.Dependencies) do
              
        if(not depMod:IsLoaded()) then
          
          if(depFailed and Dependents[name] > 1) then
            //need to decide if we should not load the rest of our dependencies if one failed to load
          end
          
          if(depMod:HasStartupErrors() or not LoadModDependencies(depMod) and not depFailed) then

            mod:OnDependencyLoadError(name)
            depFailed = name
          end
        end
      end
    end
    
    stack[#stack] = nil

    return not depFailed and self:InternalLoadMod(mod)
  end
  
  for name,mod in pairs(RootList) do
    LoadModDependencies(mod)
  end

  //find any unvisited mods that can only be stuck in a dependency cycle islands
  //Note the node/mod that a graph starts at is random and theres no way to tell which node in the cycle is the start
  //Each node in a cycle should get visited so a cycle should only get reported once
  for name, mod in pairs(LoadableMods) do
    if(not mod.Visited and mod.Dependencies) then
      LoadModDependencies(mod)
    end
  end

end

if HotReload then
  ModLoader:SetHooks()
end