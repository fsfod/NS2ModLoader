//
//   Created by:   fsfod
//

Script.Load("lua/Utility.lua")

local values = {nil, nil, nil, nil, nil, nil, nil, nil, nil}

function RawPrint(fmt, ...)  
  if(select("#", ...) == 0) then
    Shared.Message(tostring(fmt))
  elseif(type(fmt) ~= "string" or not string.find(fmt, "%%")) then
    local count = select("#", ...)+1
    
    values[1] = ((fmt or fmt == false) and ToString(fmt)) or "nil"
    
    for i=2,count,1 do
      local value = select(i-1, ...)
      if(value == nil) then
        values[i] = "nil"
      else
        values[i] = ToString(value)
      end
    end

    Shared.Message(table.concat(values, " ", 1, count))

    for i=count,1,-1 do
      values[i] = nil
    end
  else
    Shared.Message(string.format(fmt, ...))
  end
end


Script.Load("lua/Globals.lua")
Script.Load("lua/Table.lua")

Script.Load("lua/StartupLoader.lua")
Script.Load("lua/ErrorHandling.lua")
Script.Load("lua/PathUtil.lua")
Script.Load("lua/EventUtil.lua")
Script.Load("lua/ClassHooker.lua")
Script.Load("lua/LoadTracker.lua")

Script.Load("lua/CallbackHandler.lua")

Script.Load("lua/SavedVariables.lua")


Script.Load("lua/FullModsManager.lua")

FullModsManager:Init()