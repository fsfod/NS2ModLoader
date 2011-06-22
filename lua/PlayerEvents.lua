
local HotReload = PlayerEvents

if(not PlayerEvents) then
  PlayerEvents = {}
  PlayerEvents.Callbacks = CallbackHandler:New(PlayerEvents)
end

function PlayerEvents:HookIsCommander(firstArg, ...)
  if(type(firstArg) == "table") then
    self.RegisterCallback(firstArg, "IsCommander", ...)
  else
    self.RegisterCallback("IsCommander", firstArg, ...)
  end
end



function PlayerEvents:HookEnteredReadyRoom(firstArg, ...)
  if(type(firstArg) == "table") then
    self.RegisterCallback(firstArg, "EnteredReadyRoom", ...)
  else
    self.RegisterCallback("PlayerDied", firstArg, ...)
  end
end

function PlayerEvents:HookPlayerDied(firstArg, ...)
  if(type(firstArg) == "table") then
    self.RegisterCallback(firstArg, "PlayerDied", ...)
  else
    self.RegisterCallback("PlayerDied", firstArg, ...)
  end
end

function PlayerEvents:HookTeamChanged(firstArg, ...)
  if(type(firstArg) == "table") then
    self.RegisterCallback(firstArg, "TeamChanged", ...)
  else
    self.RegisterCallback("TeamChanged", firstArg, ...)
  end
end

function PlayerEvents:HookClassChanged(firstArg, ...)
  if(type(firstArg) == "table") then
    self.RegisterCallback(firstArg, "ClassChanged", ...)
  else
    self.RegisterCallback("ClassChanged", firstArg, ...)
  end
end

function PlayerEvents:OnTeamChanged()
  local player = Client.GetLocalPlayer()
  
  if(not player) then
    RawPrint("TeamChanged %s %s", "nil", (self.CurrentTeam or "nil"))
    
    if(self.CurrentTeam) then
      self.Callbacks:Fire("TeamChanged", nil, self.CurrentTeam)
    end
    
    self.CurrentTeam = nil
  else
    local team = player and player:GetTeamNumber()
  
    RawPrint("TeamChanged %s %s", tonumber(team), (self.CurrentTeam or "nil"))

    if(team == kTeamReadyRoom and self.CurrentTeam ~= kTeamReadyRoom) then
      RawPrint("EnteredReadyRoom")
      self.Callbacks:Fire("EnteredReadyRoom", self.CurrentTeam)
    end
    
    self.Callbacks:Fire("TeamChanged", team, self.CurrentTeam)
    
    self.CurrentTeam = team
  end
end

function PlayerEvents:OnClassChanged()
  local player = Client.GetLocalPlayer()
  
  if(not player) then
    if(self.CommanderClass) then
      self.Callbacks:Fire("IsCommander", false)
    end
    
    self.CommanderClass = false
  else
    local isCommander = player:isa("Commander")
    local PlayerClass = player:GetClassName()
        
    if(isCommander ~= self.CommanderClass and (self.CommanderClass or isCommander)) then
      self.Callbacks:Fire("IsCommander", isCommander)
    end
 
    local isSpectator = player:isa("Spectator")
    local team = player:GetTeamNumber()
 
    if(isSpectator and not self.IsSpectator and team ~= kTeamReadyRoom and team == self.CurrentTeam) then
      RawPrint("PlayerDied")
      self.Callbacks:Fire("PlayerDied")
    end
 
    self.Callbacks:Fire("ClassChanged", PlayerClass, self.CurrentClass)
    
    
    self.IsSpectator = isSpectator
    self.CommanderClass = isCommander
    self.CurrentClass = PlayerClass
  end
end

if(not HotReload) then
  
  local CurrentClass, CurrentTeam
  
  Event.Hook("UpdateClient", function()
  
  	local player = Client.GetLocalPlayer()
  	
  	if(not player) then
  		if(CurrentClass) then
  			PlayerEvents:OnClassChanged()
  			CurrentClass = nil
  		end
  	else
  		if(CurrentClass ~= player:GetClassName()) then
  			PlayerEvents:OnClassChanged()
  			
  		  CurrentClass = player:GetClassName()
  		elseif(player:GetTeamNumber() ~= CurrentTeam) then
  		  PlayerEvents:OnTeamChanged()
  		  
  		  CurrentTeam = player:GetTeamNumber()
  		end
  	end
  end)
end
