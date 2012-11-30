//
//   Created by:   fsfod
//
decoda_name = "Predict"

Script.Load("lua/ModPathHelper.lua")

if(StartupLoader) then
  //StartupLoader is already loaded so a reload of lua code is happening
  StartupLoader:ReloadStarted()
end


Script.Load("lua/ModLoader_Shared.lua")

StartupLoader.FullLoadFiles = {
  "lua/Predict.lua",  
}

Script.Load("lua/PlayerEvents.lua")
Script.Load("lua/InputKeyHelper.lua")

Script.Load("lua/ModLoader.lua")
Script.Load("lua/ModEntry.lua")


ModLoader:Init()

StartupLoader:Activate()