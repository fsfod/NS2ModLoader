
NS2IOLoader = {
  MarkerFile = "NS2_IO.dll",
  DefaultDirectory = "ModLoader",
  ModulePath = "NS2_IO.dll",
  EntryPoint = "luaopen_NS2_IO"
}

local ForwardSlash, BackSlash = string.byte("/"), string.byte("\\")

local function JoinPaths(path1, path2)

	local firstChar = string.byte(path2) 
	
	if(path1 == "") then
	  return path2
	end
	
	if(firstChar == ForwardSlash or firstChar == BackSlash) then
		local lastChar = string.byte(path1, #path1)
		
		if(lastChar == ForwardSlash or lastChar == BackSlash) then
			return path1..string.sub(path2, 2)
		else
			return path1..path2
		end
	else
		local lastChar = string.byte(path1, #path1)
		
		if(lastChar == ForwardSlash or lastChar == BackSlash) then
			return path1..path2
		else
			return path1.."/"..path2
		end
	end
end

function NS2IOLoader:TryLoad(BasePath)
  assert(type(BasePath) == "string" and BasePath ~= "")
  
  local ModuleEntryPoint, msg, where = package.loadlib(JoinPaths(BasePath, self.ModulePath), self.EntryPoint)
  
  if(ModuleEntryPoint) then
		 local result
		 result, msg = pcall(ModuleEntryPoint)
		 
		 if(result) then
		   self.Loaded = true
		  return true
		 end
  end
  
  return false, msg
end

function NS2IOLoader:Load()

  if(self.Loaded) then
    return true
  end

  local BasePath, result, errorMsg

  if(not self:FileExists(self.MarkerFile)) then
    return false, string.format("Marker file %s does not seem to exist in the mods directory does not seem to of been fully extracted/copyed correctly", self.MarkerFile)
  end

  if(self:FileExists("ModPath.lua")) then
    Script.Load("ModPath.lua")
    
    if(ModPath and type(ModPath) == "string" and ModPath ~= "") then
      BasePath = ModPath
    end
  end

  if(not BasePath) then
    BasePath = self.DefaultDirectory
    
    if(not self:FileExists(JoinPaths(JoinPaths("..", self.DefaultDirectory), self.MarkerFile))) then
      return false, string.format("Mod was not launched the with helper bat or extracted to a directory named %s in the Natural Selection 2 directory.", self.DefaultDirectory)
    end
  end

  return self:TryLoad(BasePath)
end

--this fails if -game is a zip, max seems to of not implemented file matching for zips
function NS2IOLoader:FileExists(file)
  local matchingFiles = {}
  
  Shared.GetMatchingFileNames(file, false, matchingFiles)
  
  local lfile = file:lower()
  
  for _,path in ipairs(matchingFiles) do
    if(path:lower() == lfile) then
      return true
    end
  end
  
  return false
end