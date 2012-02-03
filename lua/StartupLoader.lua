//
//   Created by:   fsfod
//

if(not StartupLoader) then
  
  StartupLoader = {
    Active = false,
   
    ReducedLuaList = {
      "lua/Globals.lua",
      "lua/MainMenu.lua",
      "lua/GUIManager.lua",
      "lua/menu/MouseTracker.lua",
    },
    
    FullLoadFiles = {
      "lua/Client.lua",
    }
    
    
  }
  
  StartupLoader.IsMainVM = decoda_name == "Main"
else
  if(StartupLoader.Active) then
    StartupLoader:ClearHooks()
  end
end

function StartupLoader:ActivateEmbededMode()
  
  if(self.Active) then
      Shared.Message("StartupLoader is already active")
    return
  end
  
  //we defer all our work til our LoadComplete hook is called since mod loader needs access to the Client.GetOption functions 
  self.EmbededMode = true
end

function StartupLoader:Activate()

  if(self.Active) then
      Shared.Message("StartupLoader is already active")
    return
  end

  if(self.IsMainVM) then
    self:Activate_MainVMMode()
  else
    self:Activate_ClientVMMode()
  end

end

function StartupLoader:Activate_MainVMMode()
  
  self.gRenderCamera = Client.CreateRenderCamera()
  
  self:SetHooks()

  for i,script in ipairs(self.ReducedLuaList) do
    Script.Load(script)
  end

  ClassHooker:OnLuaFullyLoaded()

  ModLoader:UILoadingStarted()
  
  self.Active = true
end

function StartupLoader:Activate_ClientVMMode()

  for i,script in ipairs(self.FullLoadFiles) do
    Script.Load(script)
  end

  ClassHooker:OnLuaFullyLoaded()

  if(ModLoader) then
    ModLoader:OnClientLuaFinished()
  end
end

Event.Hook("LoadComplete", function(errorMsg) StartupLoader:LoadComplete(errorMsg) end)

function StartupLoader:LoadComplete(errorMsg)

  self.LoadCompleted = true

  ClassHooker:ClientLoadComplete()

  if(ModLoader) then
    ModLoader:OnClientLoadComplete(errorMsg)
  end

  if(self.StartupCompleteCallback) then
    self.StartupCompleteCallback(errorMsg)
  end
end

function StartupLoader.DefaultCompleteCallback()
  
end

function StartupLoader:SetReducedLuaList(list)
  assert(type(list) == "table")
  
  self.ReducedLuaList = list
end

function StartupLoader:AddReducedLuaScript(scriptPath)
  assert(type(scriptPath) == "string")

  table.insert(self.ReducedLuaList, scriptPath)
end


function StartupLoader.OnUpdateRender()
 
  local renderCamera = StartupLoader.gRenderCamera
  
  local cullingMode = RenderCamera.CullingMode_Occlusion
  local camera      = MenuManager.GetCinematicCamera()
  
  if camera ~= false then
  
      renderCamera:SetCoords( camera:GetCoords() )
      renderCamera:SetFov( camera:GetFov() )
      renderCamera:SetNearPlane( 0.01 )
      renderCamera:SetFarPlane( 10000.0 )
      renderCamera:SetCullingMode(cullingMode)
      Client.SetRenderCamera(renderCamera)
      
  else
      Client.SetRenderCamera(nil)
  end

end

function StartupLoader.OnSendKeyEvent(key, down)

  local eventHandled, isRepeat = InputKeyHelper:PreProcessKeyEvent(key, down)

  if(not eventHandled and GUIMenuManager) then
    eventHandled = GUIMenuManager:SendKeyEvent(key, down, isRepeat)
  end

  return eventHandled
end

function StartupLoader.SendCharacterEvent(...)
  
  if(GUIMenuManager) then
    return GUIMenuManager:SendCharacterEvent(...)
  end
  
  return false
end

function StartupLoader.Update()

  if(GUIMenuManager) then
    GUIMenuManager:Update()
  end
end

function StartupLoader:SetHooks()

  Event.Hook("UpdateRender", self.OnUpdateRender)

  if(GUIMenuManager) then
    Event.Hook("SendKeyEvent", self.OnSendKeyEvent)
    Event.Hook("SendCharacterEvent", self.SendCharacterEvent)
  end
end

function StartupLoader:ClearHooks()

  Event.RemoveHook("UpdateRender", self.OnUpdateRender)
  
  if(GUIMenuManager) then
    Event.RemoveHook("SendKeyEvent", self.OnSendKeyEvent)
    Event.RemoveHook("SendCharacterEvent", self.SendCharacterEvent)
  end
end

--reset the hooks if were hot reloading
if(StartupLoader.Active) then
  StartupLoader:SetHooks()
end