//
//   Created by:   fsfod
//
__ModFolderName = "ModLoader"

Script.Load("lua/PathUtil.lua")
Script.Load("lua/ModPathHelper.lua")

if(StartupLoader) then
  //StartupLoader is already loaded so a reload of lua code is happening
  StartupLoader:ReloadStarted()
end

Script.Load("lua/ModuleBootstrap.lua")


Script.Load("lua/ModLoader_Shared.lua")

Script.Load("lua/ModLoader.lua")
Script.Load("lua/ModEntry.lua")

ModLoader:Init()

StartupLoader:Activate()
