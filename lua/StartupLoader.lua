
if(not StartupLoader) then
  
  StartupLoader = {
    Active = false,
   
    ReducedLuaList = {},
    
    FullLoadFiles = {
      "lua/Client.lua",
    }
  }
else
  if(StartupLoader.Active) then
    StartupLoader:ClearHooks()
  end
end

function StartupLoader:Activate()

  if(self.Active) then
      Shared.Message("StartupLoader is already active")
    return
  end

  self.gRenderCamera = Client.CreateRenderCamera()

  ClassHooker:HookFunction("Client", "Connect", self, "LoadFullGameCode")

  ClassHooker:HookFunction("Client", "StartServer", self, "LoadFullGameCode")

  for i,script in ipairs(self.ReducedLuaList) do
    Script.Load(script)
  end

  self:SetHooks()

  ModLoader:UILoadingStarted()

  if(GUIMenuManager) then
    GUIMenuManager:ShowMenu()
  end
  
  self.Active = true
end

function StartupLoader:LoadFullGameCode()

  if(not self.Active) then
    return
  end

   Client.DestroyRenderCamera(self.gRenderCamera)

  self:ClearHooks()

  self.Active = false

  for i,script in ipairs(self.FullLoadFiles) do
    Script.Load(script)
  end

  ClassHooker:OnLuaFullyLoaded()

  if(ModLoader) then
    ModLoader:OnClientLuaFinished()
  end
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
 
   local cullingMode = RenderCamera.CullingMode_Occlusion

   local gRenderCamera = StartupLoader.gRenderCamera

   local camera = MenuManager.GetCinematicCamera()

    if(camera ~= false) then
      
       gRenderCamera:SetCoords( camera:GetCoords() )
       gRenderCamera:SetFov( camera:GetFov() )
       gRenderCamera:SetNearPlane( 0.01 )
       gRenderCamera:SetFarPlane( 10000.0 )
       gRenderCamera:SetCullingMode(cullingMode)
       
       Client.SetRenderCamera(gRenderCamera)
   else
       Client.SetRenderCamera(nil)
   end
   

end

function StartupLoader.OnSendKeyEvent(key, down)

  local eventHandled, isRepeat, wheelDirection = InputKeyHelper:PreProcessKeyEvent(key, down)

  return eventHandled or GUIMenuManager:SendKeyEvent(key, down, isRepeat, wheelDirection)
end

function StartupLoader.SendCharacterEvent(...)
  return GUIMenuManager:SendCharacterEvent(...)
end

function StartupLoader.Update()
   GUIMenuManager:Update()
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