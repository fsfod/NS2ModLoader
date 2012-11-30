//
//   Created by:   fsfod
//

decoda_name = decoda_name or "Client"

Script.Load("lua/ModPathHelper.lua")

if(StartupLoader) then
  //StartupLoader is already loaded so a reload of lua code is happening
  StartupLoader:ReloadStarted()


  //clean up max's mess since theres no guard around MenuManager table declartion
  //the old cinematic is not destroyed and also not rendered because theres no long a record of its camera
  if(MenuManager) then
    MenuManager.SetMenuCinematic(nil)
  end
end


Script.Load("lua/ModLoader_Shared.lua")

Script.Load("lua/PlayerEvents.lua")
Script.Load("lua/InputKeyHelper.lua")

Script.Load("lua/ModLoader.lua")
Script.Load("lua/ModEntry.lua")


ModLoader:Init()

StartupLoader.StartupCompleteCallback = function(msg, IsLuaReload)

  if(IsLuaReload and StartupLoader.IsMainVM) then
    MenuManager.SetMenuCinematic("cinematics/main_menu.cinematic")
   return
  end

  if(StartupLoader.IsMainVM) then
    MenuMenu_PlayMusic("Main Menu")
    MenuManager.SetMenuCinematic("cinematics/main_menu.cinematic")
   
    MainMenu_Open()
  else
    GameGUIManager:Activate()
  end
end

StartupLoader:Activate()