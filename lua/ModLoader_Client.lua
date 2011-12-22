//
//   Created by:   fsfod
//
__ModFolderName = "ModLoader"

Script.Load("lua/PathUtil.lua")
Script.Load("lua/ModPathHelper.lua")

Script.Load("lua/ModuleBootstrap.lua")

local success, msg = ModuleBootstrap:LoadModule("NS2_IO", true)

if(not success) then
	Shared.Message("Stopping because NS2_IO encounted error: "..(msg or "unknown error"))
 return
end

Script.Load("lua/StartupLoader.lua")

Script.Load("lua/ModLoader_Shared.lua")

Script.Load("lua/PlayerEvents.lua")
Script.Load("lua/InputKeyHelper.lua")

Script.Load("lua/ModLoader.lua")
Script.Load("lua/ModEntry.lua")

ModLoader:Init()

StartupLoader:Activate()
/*
Script.Load("lua/Client.lua")
ModLoader:OnClientLuaFinished()
ClassHooker:OnLuaFullyLoaded()
*/