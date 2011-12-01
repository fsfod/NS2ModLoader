
if(not FullModsManager) then

  FullModsManager = {
    EnabledMods = {},
  }
end

function FullModsManager:Init()

  /*
  self.SV = SavedVariables("FullModsManager", {"EnabledMods"}, self)
	self.SV:Load()
	
	self:ScanForFullMods()

	if(Server) then
	  self.SV.AutoSave = false

	  self:MountFileSets(self.EnabledMods)
	end
*/
end

local modsFolderName = "FullMods"

function FullModsManager:ScanForFullMods()
  
  local luaFiles = {}

  Shared.GetMatchingFileNames(modsFolderName.."/*.lua", true, luaFiles)

  local ModList = {}
  self.Mods = ModList

  local modNameStart = 2+#modsFolderName

  for _,filePath in ipairs(luaFiles) do
    local nameEnd = string.find(filePath, "/", modNameStart+1)
    
    if(nameEnd) then
      local modName = string.sub(filePath, modNameStart, nameEnd-1)
    
      local modFileList = ModList[modName]
    
      if(not modFileList) then
        modFileList = {}
        ModList[modName] = modFileList
      end
 
      local normlizedPath = filePath:sub(nameEnd+1):lower()
      
      //just use the mod name  instead of just setting it to true so we can reuse the mod table later
      modFileList[normlizedPath] = modName
    end
  end
end

function FullModsManager:CheckConflicts(modNames)
    
  local scriptList = {}
  local conflicts = {}
    
  for name,enabled in pairs(modNames) do
    
    if(enabled) then
    
      assert(self.Mods[name], "No mod named "..name)
      
      for scriptPath,_ in pairs(self.Mods[name]) do
        
        if(not scriptList[scriptPath]) then
          scriptList[scriptPath] = name
        else
          
          local listEntry = conflicts[scriptPath]
          
          if(not listEntry) then
            listEntry =  {}
            listEntry[scriptList[scriptPath]] = true
            
            conflicts[scriptPath] = listEntry
          end
          
          listEntry[name] = true
        end        
      end
      
    end
  end


  return (next(conflicts) and conflicts) or nil
end

function FullModsManager:MountEnabledMods()
  self:MountFileSets(self.EnabledMods)
end

function FullModsManager:MountFileSets(modNames, overridePriorty)

  assert(not self.FilesMounted, "mods scripts have already been mounted")

  overridePriorty = overridePriorty or {}

  for name,enabled in pairs(modNames) do
    
    if(enabled) then

      for scriptPath,_ in pairs(self.Mods[name]) do
      
        //if the script is not in overridePriorty list or its value of in it is the current mods name we mount it
        if(not overridePriorty[scriptPath] or overridePriorty[scriptPath] == name) then
          LoadTracker:SetFileOverride(scriptPath, string.format("%s/%s/%s", modsFolderName, name, scriptPath))
        end
      end
      
    end
  end

  self.FilesMounted = true
end

function FullModsManager:EnableMod(name)
  assert(type(name) == "string")
    
  self.EnabledMods[name] = true 
  
  self.SV:Save()
  
  self.CurrentConflicts = self:CheckConflicts(self.EnabledMods)
end

function FullModsManager:DisableMod(name)
  assert(type(name) == "string")
  
  self.EnabledMods[name] = false
  
  self.SV:Save()

  self.CurrentConflicts = self:CheckConflicts(self.EnabledMods)
end

function FullModsManager:GetModInfo(modName)

  local conflicts = self.CurrentConflicts
  
  if(conflicts) then
    local count = 0
    
    for scriptPath,modList in pairs(conflicts) do
     
      if(modList[modName]) then
        count = count+1
      end
    end
    
    conflicts = count
  end
  
  return not self.EnabledMods[modName], modName, conflicts or 0
end

function FullModsManager:GetModList()

  if(not self.Mods) then
    self:ScanForFullMods()
  end

  local list = {}

  for name,_ in pairs(self.Mods) do
    table.insert(list, name)
  end
  
  return list
end
