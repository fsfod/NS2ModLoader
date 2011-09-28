local HotReload = false

local Mods, ActiveMods, OrderedActiveMods

if(not ModLoader) then
	ModLoader = {
		DisabledMods = {},
		OrderedActiveMods = {},
		ActiveMods = {},
		Mods = {},
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

local VMName = (Server and "server") or "client"
local OppositeVMName = (Server and "Client") or "Server"


function ModLoader:Init()
	self.SV = SavedVariables("ModLoader", {"DisabledMods"}, self)

	self.SV:Load()

  self:SetupConsoleCommands()

	self:ScannForMods()
	self:LoadMods()
	
	self:SetHooks()
end

function ModLoader:Init_EmbededMode(registeredMods)
  self.Embeded = true
  
  self:SetupConsoleCommands()
  self:SetHooks()

  if(registeredMods) then
    for _,mod in ipairs(registeredMods) do
      self:AddModFromDir(unpack(mod))
    end
  end
  
  
  self:ScannForMods()
  self:LoadMods()
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
    Client.ConsoleCommand(ConsoleCmd)
  end
end

function ModLoader:GetListOfActiveMods()
  
  local list = {}

  for name,mod in pairs(self.OrderedActiveMods) do
    list[#list+1] = name
  end

  return list
end

function ModLoader:IsModEnabled(name)
  return not self.DisabledMods[name:lower()]
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
  
  local disabled = self.DisabledMods[name]
  
  if(disabled == nil) then
    disabled = false
  end
  
  
  return disabled, modentry.Name, modentry.LoadState
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
		elseif(self.DisabledMods[name]) then
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

	for dirname,Source in pairs(NS2_IO.FindDirectorys("/Mods/","")) do
 		
		local modinfopath = string.format("/Mods/%s/modinfo.lua", dirname)
		
		if(not Source:FileExists(modinfopath)) then
			RawPrint("Skiping mod directory \"%s\" that has no modinfo.lua in it", dirname)
		else
		  self.Mods[dirname:lower()] = CreateModEntry(Source, dirname)
		end
	end
	
	local SupportedArchives = NS2_IO.GetSupportedArchiveFormats()
	
	--scan for mods are contained in archives that are in our "Mods" folder
	for fileName,Source in pairs(NS2_IO.FindFiles("/Mods/","")) do
	
		if(SupportedArchives[(GetExtension(fileName) or ""):lower()]) then
			local success, archiveOrError = pcall(NS2_IO.OpenArchive, Source, "/Mods/"..fileName)
	
			if(success) then
				if(archiveOrError:FileExists("modinfo.lua")) then
					local modname = StripExtension(fileName)
					
					self.Mods[modname:lower()] = CreateModEntry(archiveOrError, modname, true)
				else
				  local dirlist = archiveOrError:FindDirectorys("", "")
				  local modname = dirlist[1]
				  --if theres no modinfo.lua in the root of the archive see if the archive contains a single directory that has a modinfo.lua in it
				  if(#dirlist == 1 and archiveOrError:FileExists(modname.."/modinfo.lua")) then
				    self.Mods[modname:lower()] = CreateModEntry(archiveOrError, modname, true, modname.."/")
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

function ModLoader:UILoadingStarted()
  self:DispatchModCallback("OnUILoading")
end

function ModLoader:OnClientLuaFinished()
	self:DispatchModCallback("OnClientLuaFinished")
end

function ModLoader:OnServerLuaFinished()
	self:DispatchModCallback("OnServerLuaFinished")
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

function ModLoader:LoadMods()

  local LoadableMods = {}
  --a hashtable The key is the name of mod. the value a keyvalue list of mods that depend on the mod
  local Dependents = {}
  local modList = {}

  for modname,entry in pairs(self.Mods) do
		if entry:LoadModinfo() and not self.DisabledMods[modname] and entry:CanLoadInVm(VMName) then

		  if(entry.Dependencies) then
		    for name,_ in pairs(entry.Dependencies) do
		      if(not Dependents[name]) then
		        Dependents[name] = {}
		      end
		      
		      Dependents[name][modname] = entry
        end
        
        LoadableMods[modname] = entry
      else
        modList[#modList+1] = modname   
		  end
		end
	end

  local loadResult = {}

	self:SortAndLoadModList(modList, loadResult)

  if(next(Dependents)) then
    self:HandleModsDependencies(LoadableMods, Dependents, loadResult)
  end
end

function ModLoader:SortAndLoadModList(list, loadResult)
 
  table.sort(list)

  local ordered = self.OrderedActiveMods

  for _,modname in pairs(list) do
    local entry = self.Mods[modname]
    
    RawPrint("Loading mod: "..entry.Name)
    
    local loaded = entry:Load() 
        
	  if(loaded) then
	    ordered[#ordered+1] = entry
	  end
	  
	  loadResult[modname] = loaded
  end
end

function ModLoader:HandleModsDependencies(LoadableMods, Dependents, loadResults)
  
  local MissingDependencies = {}
  local RootList = {}
	
	local PropagateUnloadable

	PropagateUnloadable = function(modname, notFirst)
		for name,mod in pairs(Dependents[modname]) do
      mod:OnDependencyLoadError(modname)
      LoadableMods[name] = nil
     
      if(Dependents[name]) then
        PropagateUnloadable(name, true)
      end
    end
	end


  for modname,list in pairs(Dependents) do
    local RequiredMod = LoadableMods[modname]
    
    if(not RequiredMod) then
      //this mod has already been loaded successfuly so remove it from the graph
      if(loadResults[modname]) then

        for dependentName,mod in pairs(list) do
          
          local deps = mod.Dependencies

          if(deps) then
            //remove link to us
            deps[modname] = nil

            //if we were the last remaining dependency of this mod add it as a root node
            if(not next(deps)) then
              RootList[#RootList+1] = self.Mods[dependentName]
              mod.Dependencies = false
            end
          end
        end

      else
        --This dependency was missing or had load errors so mark all the dependents unloadable
        PropagateUnloadable(modname)
      end

      Dependents[modname] = nil
    else
      --if it has no Dependencies it must be a root node
      if(RequiredMod.Dependencies == nil) then
        RootList[#RootList+1] = RequiredMod
      end
    end
  end

  local NodeList = {}
  local OrderedActiveMods = self.OrderedActiveMods
  
  for modname,entry in pairs(LoadableMods) do
		local DependentList = Dependents[modname]

    if(DependentList) then
      --clear out any dependent mods that aren't loadable anymore because they are missing a Dependencies
      for name,mod in pairs(DependentList) do
        if(not LoadableMods[name] and not loadResults[modname]) then
          DependentList[name] = nil
        end
      end

      --TODO handle when all dependents have become non loadable
      entry.Dependents = DependentList
    end

    if DependentList or entry.Dependencies then
     --build up a list of nodes for our topological sort
		  NodeList[modname] = entry
		end
	end

  local Sorted = {}
  
  while next(NodeList) or #RootList ~= 0 do
    
    if(#RootList == 0) then
      error("circular mod dependency detected")
    end
    
    --deque next root node
    local node = table.remove(RootList, 1)
    local modname = node.InternalName
    
    Sorted[#Sorted+1] = node

    if(node.Dependents) then
      for name,childnode in pairs(node.Dependents) do
        local ParentList = childnode.Dependencies
        
        --remove the parent link to us
        if(ParentList) then
          ParentList[modname] = nil      
        end
        
        --if the node has no more parent links add it to the root list
        if(not ParentList or not next(ParentList)) then
          table.insert(RootList, childnode)
        end
        
        node.Dependents[name] = nil
      end
    end
    
    NodeList[modname] = nil
  end

  for _,entry in ipairs(Sorted) do 

    if(not entry:IsLoaded() and not entry:HasStartupErrors()) then
		  RawPrint("Loading mod: "..entry.Name)

		  if(entry:Load()) then
		    OrderedActiveMods[#OrderedActiveMods+1] = entry 
		  end
		end
	end
end

if HotReload then
  ModLoader:SetHooks()
end