Script.Load("NS2_IO.lua")

if(not NS2_IO) then
	Shared.Message("Stopping because NS2_IO is not loaded")
 return
end


Script.Load("lua/ModLoader_Shared.lua")

Script.Load("lua/PlayerEvents.lua")
Script.Load("lua/ModLoader.lua")
Script.Load("lua/ModEntry.lua")

ModLoader:Init()

Script.Load("lua/Client.lua")
ModLoader:OnClientLuaFinished()
ClassHooker:OnLuaFullyLoaded()
