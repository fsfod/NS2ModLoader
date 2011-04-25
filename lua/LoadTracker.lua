
LoadTracker = {
	LoadStack = {},
	LoadedScripts = {},
	
	LoadedFileHooks = {},
	OverridedFiles = {},
}


LoadTracker.NormalizePath = NormalizePath

local orignalLoad = Script.Load

Script.Load = function(scriptPath)
	
	local normPath = NormalizePath(scriptPath)
	local NewPath = LoadTracker:ScriptLoadStart(normPath, scriptPath)
	
	local ret
	
	if(NewPath) then
		ret = orignalLoad(NewPath)
	end
	
	assert(ret ==  nil)
	
	LoadTracker:ScriptLoadFinished(normPath)
end

function LoadTracker:ScriptLoadStart(normalizedsPath, unnormalizedsPath)
	table.insert(self.LoadStack, normalizedsPath)
	
	--store the stack index so we can be sure were not reacting to a double load of the same file
	if(not self.LoadedScripts[normalizedsPath]) then
		self.LoadedScripts[normalizedsPath] = #self.LoadStack
		
		local FileOverride = self.OverridedFiles[normalizedsPath]
		
		if(FileOverride) then
			if(type(FileOverride) ~= "table") then
			 return FileOverride
			else
				RunScriptFromSource(FileOverride[1], FileOverride[2])
			 return false
			end
		end
	else
		--block a double load of an override
		if(self.OverridedFiles[normalizedsPath]) then
			return false
		end
	end
	
	return unnormalizedsPath
end

function LoadTracker:HookFileLoadFinished(scriptPath, selfTable, funcName)
	
	local path = NormalizePath(scriptPath)
	
	if(self.LoadedScripts[tobeNorm]) then
		error("cannot set FileLoadFinished hook for "..scriptPath.." because the file is already loaded")
	end
	
	if(not self.LoadedFileHooks[path]) then
		self.LoadedFileHooks[path] = {{selfTable, selfTable[funcName]}}
	else
		table.insert(self.LoadedFileHooks[path], {selfTable, selfTable[funcName]})
	end
end

function LoadTracker:SetFileOverride(tobeReplaced, overrider, overriderSource)
	
	local tobeNorm = NormalizePath(tobeReplaced)
	
	if(self.LoadedScripts[tobeNorm]) then
		error("cannot set file override for "..tobeReplaced.." because the file is already loaded")
	end
	
	if(self.OverridedFiles[tobeNorm]) then
		error(string.format("Cannot override %s because its already been overriden by %s", tobeReplaced, self.OverridedFiles[tobeReplaced]))
	end
	
	local entry = overrider
	
	if(overriderSource) then
		entry = {overriderSource, overrider}
	end
	
	self.OverridedFiles[tobeNorm] = entry
end

function LoadTracker:ScriptLoadFinished(normalizedsPath)

	--make sure that were not getting a nested double load of the same file
	if(self.LoadedScripts[normalizedsPath] == #self.LoadStack) then
		if(self.LoadedFileHooks[normalizedsPath]) then
			for _,hook in ipairs(self.LoadedFileHooks[normalizedsPath]) do
				hook[2](hook[1])
			end
		end
		
		if(ClassHooker) then
			ClassHooker:ScriptLoadFinished(normalizedsPath)
		end
		
		self.LoadedScripts[normalizedsPath] = true
	end

	table.remove(self.LoadStack)

end

function LoadTracker:GetCurrentLoadingFile()
	return self.LoadStack[#self.LoadStack]
end