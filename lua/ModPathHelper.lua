//
//   Created by:   fsfod
//

Script.Load("lua/PathUtil.lua")

if(not __ModPath and FileExists("ModPath.lua")) then
  Script.Load("ModPath.lua")
end

if(not __ModPath and __ModFolderName and (FileExists("../ns2.exe") or FileExists("../server.exe"))) then
  __ModPath = __ModFolderName.."/"
end

if(not __ModPath) then
  Shared.Message("Could not determine the path for __ModPath, Lua dll module loading will be non functional")
  Shared.Message("This is caused by either this mod was not being launched with the bat in the mod directory or this mod was not extracted to the Natural Selection 2 directory")
end

