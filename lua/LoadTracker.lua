//
//   Created by:   fsfod
//

local HotReload = LoadTracker

local Version = "1.0"

if(not LoadTracker) then
  LoadTracker = {
    Version = Version,
    LoadStack = {},
    LoadedScripts = {},
    
    LoadAfterScripts = {},
    LoadedFileHooks = {},
    OverridedFiles = {},
    BlockedScripts = {},
  }
else
  //make sure this is not diffent version of LoadTracker being loaded with another one already loaded
  assert(LoadTracker.Version == Version)
  //clear loaded scripts since were at the start of a hot reload
  LoadTracker.LoadedScripts = {}
end

local ForwardSlash = string.byte("/")

local function NormalizePath(luaFilePath)

  local path = string.gsub(luaFilePath, "\\", "/")
  path = path:lower()

  if(string.byte(path) == ForwardSlash) then
    path = path:sub(2)
  end

  return path
end

LoadTracker.NormalizePath = NormalizePath


//This function is called by our Script.Load hook if we return false the hook blocks the script from loading
function LoadTracker:ScriptLoadStart(normalizedPath, unnormalizedPath)
  table.insert(self.LoadStack, normalizedPath)
  
  if(self.BlockedScripts[normalizedPath]) then
    return false
  end
  
  --store the stack index so we can be sure were not reacting to a double load of the same file
  if(not self.LoadedScripts[normalizedPath]) then
    self.LoadedScripts[normalizedPath] = #self.LoadStack
    
    local FileOverride = self.OverridedFiles[normalizedPath]
    
    if(FileOverride) then
      if(type(FileOverride) ~= "table") then
        return FileOverride
      else
        RunScriptFromSource(FileOverride[1], FileOverride[2])
       return false
      end
    end
  else
    --block a double load of an override
    if(self.OverridedFiles[normalizedPath]) then
      return false
    end
  end
  
  return unnormalizedPath
end

function LoadTracker:HookFileLoadFinished(scriptPath, selfOrFunc, funcName)
  
  local path = NormalizePath(scriptPath)
  
  if(self.LoadedScripts[tobeNorm]) then
    error("cannot set FileLoadFinished hook for "..scriptPath.." because the file is already loaded")
  end

  local tbl = self.LoadedFileHooks[path]

  if(not tbl) then
    tbl = {}
    self.LoadedFileHooks[path] = tbl
  end

  if(funcName) then
    table.insert(tbl, function() selfOrFunc[funcName](selfOrFunc) end)
  else
    table.insert(tbl, selfOrFunc)
  end

end

function LoadTracker:LoadScriptAfter(scriptPath, afterScriptPath, afterScriptSource)

  local normPath = NormalizePath(scriptPath)
  
  if(self.LoadedScripts[normPath]) then
    error("cannot set LoadScriptAfter for "..scriptPath.." because the file is already loaded")
  end

  local entry = afterScriptPath

  if(afterScriptSource) then
    entry = {afterScriptSource, afterScriptPath}
  end
  
  local loadAfterList = self.LoadAfterScripts[normPath] 
  
  if(not loadAfterList) then
    loadAfterList = {}
    self.LoadAfterScripts[normPath] = loadAfterList
  end
  
   loadAfterList[#loadAfterList+1] = entry
end


function LoadTracker:SetFileOverride(tobeReplaced, overrider, overriderSource)
  
  assert(overrider and type(overrider) == "string" and overrider ~= "")
  
  local tobeNorm = NormalizePath(tobeReplaced)
  
  if(self.LoadedScripts[tobeNorm]) then
    error("cannot set file override for "..tobeReplaced.." because the file is already loaded")
  end
  
  if(self.OverridedFiles[tobeNorm]) then
    error(string.format("Cannot override %s because its already been overriden by %s", tobeReplaced, self.OverridedFiles[tobeReplaced]))
  end
  
  local entry = overrider
  
  if(overriderSource) then
    entry = {overriderSource, overrider}
  end
  
  self.OverridedFiles[tobeNorm] = entry
end

function LoadTracker:BlockScriptLoad(scriptPath)
  
  local tobeNorm = NormalizePath(scriptPath)
  
  if(self.LoadedScripts[tobeNorm]) then
    error("cannot block script "..scriptPath.." because the script is already loaded")
  end
  
  if(self.OverridedFiles[tobeNorm]) then
    error(string.format("cannot block script %s because its already been overriden by %s", tobeReplaced, self.OverridedFiles[tobeReplaced]))
  end

  self.BlockedScripts[tobeNorm] = true
end

function LoadTracker:ScriptLoadFinished(normalizedPath)

  --make sure that were not getting a nested double load of the same file
  if(self.LoadedScripts[normalizedPath] == #self.LoadStack) then
    if(self.LoadedFileHooks[normalizedPath]) then
      for _,hook in ipairs(self.LoadedFileHooks[normalizedPath]) do
        hook()
      end
    end

    local LoadAfter = self.LoadAfterScripts[normalizedPath]

    if(LoadAfter) then
      for _,entry in ipairs(LoadAfter) do
        if(type(entry) ~= "table") then
          Script.Load(entry)
        else
          RunScriptFromSource(entry[1], entry[2])
        end
      end
    end
    
    if(ClassHooker) then
      ClassHooker:ScriptLoadFinished(normalizedPath)
    end
    
    self.LoadedScripts[normalizedPath] = true
  end

  table.remove(self.LoadStack)
end

function LoadTracker:GetCurrentLoadingFile()
  return self.LoadStack[#self.LoadStack]
end

if(not HotReload) then

  local Script_Load = Script.Load
  
  Script.Load = function(scriptPath)
    //just let the real script.load bomb on bad paramters
    if(not scriptPath or type(scriptPath) ~= "string") then
      Script_Load(scriptPath)
    end
    
    local normPath = NormalizePath(scriptPath)
    local newPath = LoadTracker:ScriptLoadStart(normPath, scriptPath)
    
    local ret
    
    if(newPath) then
      ret = Script_Load(newPath)
    end
    
    assert(ret == nil)
    
    LoadTracker:ScriptLoadFinished(normPath)
  end
end