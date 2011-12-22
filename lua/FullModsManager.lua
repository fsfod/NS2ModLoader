//
//   Created by:   fsfod
//

if(not FullModsManager) then

  FullModsManager = {
    EnabledMods = {},
    ModSources = {},
  }
end

function FullModsManager:Init()
  
  if(not SavedVariables) then
    return
  end
  
  self.SV = SavedVariables("FullModsManager", {"EnabledMods"}, self)
	self.SV:Load()
	
	self:ScanForFullMods()

	if(Server) then
	  self.SV.AutoSave = false

	  self:MountFileSets(self.EnabledMods)
	end

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
  
  self:ScannFullModArchives()
end

function FullModsManager:ScannFullModArchives()

  local SupportedArchives = {
		  [".zip"] = true,
		  [".rar"] = true,
		  [".7ip"] = true,
	}
	
	matchingFiles = {}
	
	Shared.GetMatchingFileNames(modsFolderName.."/*.*", false, matchingFiles)

	--scan for mods are contained in archives that are in our "Mods" folder
	for _,path in ipairs(matchingFiles) do	
	  local fileName = GetFileNameFromPath(path)
	
		if(SupportedArchives[(GetExtension(fileName) or ""):lower()]) then
			local success, archive = pcall(OpenArchive, path)
	
			if(success) then
			  
			  local name = StripExtension(fileName)
			  
			  if(archive:DirectoryExists("lua")) then
			    self:TryReadArchiveLuaList(name, archive, "lua")
			  else
			    local dirlist = archive:FindDirectorys("", "")
				  
				  --if theres no modinfo.lua in the root of the archive see if the archive contains a single directory that has a modinfo.lua in it
				  if(#dirlist == 1) then
				    if(archive:DirectoryExists(dirlist[1].."/lua")) then
				      self:TryReadArchiveLuaList(name, archive, dirlist[1].."/lua")
				    else
				      
				      //guessing a randomly named directory that should contain the lua files
				      self:TryReadArchiveLuaList(name, archive, dirlist[1])
				    end
				    
				  elseif(#dirlist == 0) then
				    self:TryReadArchiveLuaList(name, archive, "")
				  else
            //we could get really silly here and search each of the directorys for a lua directory and .lua files
            RawPrint("Skipping fullmod archive %s because it contains multible root directorys", fileName) 
				  end
			  end

			else
				RawPrint("error while opening fullmod archive %s :\n%s", fileName, archive)
			end
		end
		
	end
		
end

function FullModsManager:TryReadArchiveLuaList(name, archive, basePath)
  
  local fileList = archive:GetFileList(basePath, "*.lua")
  
  if(#fileList == 0) then
    return false
  end
  
  local modTable = {
    Source = archive,
    BasePath = basePath,
    
  } 
 
  local scriptList = {}
  local basepathLength = #basePath
  
  if(basePath == "lua") then
    
    for i,path in ipairs(fileList) do
      scriptList[path] = path
    end
    
  else
    
    if(basepathLength == 0) then

      //the lua files are in the root of the archive
      for i,path in ipairs(fileList) do
        scriptList["lua/"..path] = path
      end
      
    else
      
      if(string.find(basePath, "%/lua$")) then
        basepathLength = basepathLength-3
        
        for i,path in ipairs(fileList) do
          scriptList[path:sub(basepathLength)] = path
        end
        
      else
        
        for i,path in ipairs(fileList) do
          scriptList["lua/"..path:sub(basepathLength)] = path
        end
        
      end
    end
  end
  
  self.ModSources[name] = archive
  
  self.Mods[name] = scriptList
  
  return true
end

function FullModsManager:CheckConflicts(modNames)
    
  local scriptList = {}
  local conflicts = {}
    
  for name,enabled in pairs(modNames) do
    
    if(enabled and self.Mods[name]) then
    
      //assert(self.Mods[name], "No mod named "..name)
      
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
    
    if(enabled and self.Mods[name]) then

      for scriptPath,realpath in pairs(self.Mods[name]) do
      
        //if the script is not in overridePriorty list or its value of in it is the current mods name we mount it
        if(not overridePriorty[scriptPath] or overridePriorty[scriptPath] == name) then
          
          if(not self.ModSources[name]) then
            
            LoadTracker:SetFileOverride(scriptPath, string.format("%s/%s/%s", modsFolderName, name, scriptPath))
            
          else
            
            LoadTracker:SetFileOverride(scriptPath, realpath, self.ModSources[name])
            
          end
          
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
