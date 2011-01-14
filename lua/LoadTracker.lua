
LoadTracker = {
	LoadStack = {},
	LoadedScripts = {},
	
	LoadedFileHooks = {},
	ReplacedFiles = {},
}


LoadTracker.NormalizePath = NormalizePath

local orignalLoad = Script.Load

Script.Load = function(scriptPath)
	
	local normPath = NormalizePath(scriptPath)
	local NewPath = LoadTracker:ScriptLoadStart(normPath)
	
	if(NewPath) then
		orignalLoad(NewPath)
	end
	
	LoadTracker:ScriptLoadFinished(normPath)
end

function LoadTracker:ScriptLoadStart(normalizedsPath)
	table.insert(self.LoadStack, normalizedsPath)
	
	--store the stack index so we can be sure were not reacting to a double load of the same file
	if(not self.LoadedScripts[normalizedsPath]) then
		self.LoadedScripts[normalizedsPath] = #self.LoadStack
		
		local Replacer = self.ReplacedFiles[normalizedsPath]
		
		if(Replacer) then
			if(type(Replacer) ~= "table") then
			 return self.ReplacedFiles[normalizedsPath]
			else
				RunScriptFromSource(Replacer[1], Replacer[2])
			 return false
			end
		end
	end
	
	return normalizedsPath
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

function LoadTracker:SetFileReplace(tobeReplaced, replacingFile, replacingSource)
	
	local tobeNorm = NormalizePath(tobeReplaced)
	
	if(self.LoadedScripts[tobeNorm]) then
		error("cannot set file replace for "..tobeReplaced.." because the file is already loaded")
	end
	
	if(self.ReplacedFiles[tobeNorm]) then
		error(string.format("Cannot replace %s because its already been replaced by %s", tobeReplaced, self.ReplacedFiles[tobeReplaced]))
	end
	
	local entry = replacingFile
	
	if(replacingSource) then
		entry = {replacingSource, replacingFile}
	end
	
	self.ReplacedFiles[tobeNorm] = entry
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