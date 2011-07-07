Script.Load("NS2_IO.lua")

local success, msg = NS2IOLoader:Load()

if(not success) then
  //error("failed to load NS2_IO.dll module because of error:\n "..msg)
	Shared.Message("Stopping because NS2_IO encounted error: "..(msg or "unknown error"))
 return
end

Script.Load("lua/ModLoader_Shared.lua")

Script.Load("lua/ModLoader.lua")
Script.Load("lua/ModEntry.lua")

ModLoader:Init()

Script.Load("lua/server.lua")
ModLoader:OnServerLuaFinished()
ClassHooker:OnLuaFullyLoaded()
