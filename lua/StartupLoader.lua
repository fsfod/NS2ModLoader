
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

function StartupLoader.OnSetupCamera()

  local getCamera = MenuManager and MenuManager.GetCinematicCamera

  if(getCamera) then
    return getCamera()
  else
    return false
  end
end

function StartupLoader.OnSendKeyEvent(key, down)

  local eventHandled, isRepeat, wheelDirection = GUIManagerEx.PreProcessKeyEvent(key, down)

  return eventHandled or GUIMenuManager:SendKeyEvent(key, down, isRepeat, wheelDirection)
end

function StartupLoader.SendCharacterEvent(...)
  return GUIMenuManager:SendCharacterEvent(...)
end

function StartupLoader.Update()
   GUIMenuManager:Update()
end

function StartupLoader:SetHooks()

  Event.Hook("SetupCamera", self.OnSetupCamera)

  if(GUIMenuManager) then
    Event.Hook("SendKeyEvent", self.OnSendKeyEvent)
    Event.Hook("SendCharacterEvent", self.SendCharacterEvent)
  end
end

function StartupLoader:ClearHooks()

  Event.RemoveHook("SetupCamera", self.OnSetupCamera)
  
  if(GUIMenuManager) then
    Event.RemoveHook("SendKeyEvent", self.OnSendKeyEvent)
    Event.RemoveHook("SendCharacterEvent", self.SendCharacterEvent)
  end
end

--reset the hooks if were hot reloading
if(StartupLoader.Active) then
  StartupLoader:SetHooks()
end