local print = Shared.Message

if(not NS2_IO) then
	local ModuleEntryPoint, msg, where = package.loadlib("ModLoader/NS2_IO.dll", "luaopen_NS2_IO")
	
	if(ModuleEntryPoint) then
		ModuleEntryPoint()
	else
		--yes checking for a localized error string :( but its best we can do
		if(string.find(msg,"The specified module could not be found.")) then
			print("Unable to load NS2_IO.dll Please make sure you extacted this mod to a folder named ModLoader in your natrual selection 2 directory")
		else
			error("failed to load NS2_IO.dll module because of error:\n "..msg)
		end
	end
end