//
//   Created by:   fsfod
//

ModuleBootstrap = {
  LuabindLoaded = false,
  
  LuabindPath = false,
}

function ModuleBootstrap:HasLuabind()

  if not self.LuabindPath then
    self.LuabindPath = "luabind.dll"
  end
  
  return FileExists(self.LuabindPath)
end

function ModuleBootstrap:HasValidLuabind()

  if(self.LuabindError) then
    return false
  end

  return self:HasLuabind()
end

function ModuleBootstrap:LoadModule(moduleName, requiresLuabind, entryPoint)
  
  local name = StripExtension(moduleName)
  
  entryPoint = entryPoint or "luaopen_"..name
  
  if(not self:TryLoadLuabind()) then
    return false
  end
  
  return self:TryLoad(JoinPaths(__ModPath, name..".dll"), entryPoint)
end

function ModuleBootstrap:TryLoadLuabind()

  if(self.LuabindLoaded) then
    return true
  end

  if(self.LuabindError) then
    return false
  end

  if(not ModuleBootstrap:HasLuabind()) then
    Shared.Message("ModuleBootstrap: could not find luabind.dll to load")   
    
    self.LuabindError = "could not find luabind.dll" 
   return false
  end

  local result, errorMsg = self:TryLoad(JoinPaths(__ModPath, self.LuabindPath) , "luaopen_luabind")

  if(not result) then
    Shared.Message("ModuleBootstrap: luabind.dll failed to run(".. errorMsg ..")")
    self.LuabindError = errorMsg
    
   return false
  end
  
  self.LuabindLoaded = true
  
  return true
end

function ModuleBootstrap:TryLoad(modulePath, EntryPoint)
  assert(type(modulePath) == "string" and modulePath ~= "")
  
  local ModuleEntryPoint, msg, where = package.loadlib(modulePath, EntryPoint)
  
  if(ModuleEntryPoint) then
		local result
		 result, msg = pcall(ModuleEntryPoint)
		 
		if(result) then
		  return true, result
		end
  end
  
  return false, msg
end