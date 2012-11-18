//
//   Created by:   fsfod
//

Script.Load("lua/PathUtil.lua")

if(not __ModPath and FileExists("ModPath.lua")) then
  Script.Load("ModPath.lua")
end


if(not __ModPath and __ModFolderName) then
  
end


