
local ForwardSlash, BackSlash = string.byte("/"), string.byte("\\")

function NormalizePath(luaFilePath)

	local path = string.gsub(luaFilePath, "\\", "/")
	path = path:lower()
	
	if(string.byte(path) == ForwardSlash) then
	 path =	path:sub(2)
	end

	return path
end

function JoinPaths(path1, path2)

	local firstChar = string.byte(path2) 
	
	if(firstChar == ForwardSlash or firstChar == BackSlash) then
		local lastChar = string.byte(path1, #path1)
		
		if(lastChar == ForwardSlash or lastChar == BackSlash) then
			return path1..string.sub(path2, 2)
		else
			return path1..path2
		end
	else
		local lastChar = string.byte(path1, #path1)
		
		if(lastChar == ForwardSlash or lastChar == BackSlash) then
			return path1..path2
		else
			return path1.."/"..path2
		end
	end
end

function StripExtension(filename)

	local index = string.find(filename, "%.", -#filename)

	if(index) then
		return string.sub(filename, 1, index-1)
	end
	
	return filename
end

function GetExtension(filename)

	local index = string.find(filename, "%.", -#filename)

	if(index) then
		return string.sub(filename, index+1)
	end
end

local function WriteStackTrace() 
	Shared.Message(debug.traceback())
end

function RunScriptFromSource(source, path)
	
	local ChunkOrError = source:LoadLuaFile(path)

	if(type(ChunkOrError) == "string") then
		Shared.Message(ChunkOrError)
	 return false
	end

	--just run it in the global enviroment
	local success = xpcall(ChunkOrError, WriteStackTrace)

	
	return success
end