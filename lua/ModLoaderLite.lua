//
//   Created by:   fsfod
//




ModLoader.Embeded = true

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
	Dependencies = true,
	CanLateLoad = "boolean",
}

if(not __ModPath) then

function ModEntry:LoadModinfo()

  if(self.Modinfo) then
    return true
  end

  //wtb a Script.Load that takes an enviroment to load the script
  for name,_ in pairs(OptionalFieldList) do
    _G[name] = nil
  end

  for name,_ in pairs(RequiredFieldList) do
    _G[name] = nil
  end

  self:RunLuaFile("modinfo.lua")

  local modinfo = setmetatable({}, self.ChangeCaseMT)

  for name,_ in pairs(OptionalFieldList) do
    modinfo[name] = _G[name]
  end

  for name,_ in pairs(RequiredFieldList) do
    modinfo[name] = _G[name]
  end
  
  self.LoadState = LoadState.ModinfoLoaded

  return self:ProcessModInfo(modinfo)
end

function ModEntry:LoadMainScript()
	local fields = self.Modinfo

  self:RunLuaFile(self.Modinfo.MainScript)

	return self:MainLoadPhase()
end

end