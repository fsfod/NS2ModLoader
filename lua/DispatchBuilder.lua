DispatchBuilder = {}
 
--maybe we could create all these dispatchers as closeure
function DispatchBuilder.SingleNormal(hookData, ...)
	hookData[1](...)

	local retvalue = hookData.Orignal(...)

		if(hookData.ReturnValue) then
			retvalue = hookData.ReturnValue
			hookData.ReturnValue = nil

			if(retvalue == FakeNil) then
				retvalue = nil
			end
		end

	return retvalue
end

function DispatchBuilder.SingleClassRaw(hookData, self, ...)
	local retvalue = hookData.Orignal(self, hookData.Raw[1](self, ...))

		if(hookData.ReturnValue) then
			retvalue = hookData.ReturnValue
			hookData.ReturnValue = nil
			
			if(retvalue == FakeNil) then
				retvalue = nil
			end
		end

	return retvalue
end

function DispatchBuilder.SingleRaw(hookData, self, ...)
	local retvalue = hookData.Orignal(hookData.Raw[1](...))

		if(hookData.ReturnValue) then
			retvalue = hookData.ReturnValue
			hookData.ReturnValue = nil
			
			if(retvalue == FakeNil) then
				retvalue = nil
			end
		end

	return retvalue
end

function DispatchBuilder.SinglePost(hookData, ...)
	--Store the return value in our hookinfo so the post hook can read it if it wants
	hookData.ReturnValue = hookData.Orignal(...)
	hookData.Post[1](...)

	local retvalue = hookData.ReturnValue
	hookData.ReturnValue = nil

	return retvalue
end

function DispatchBuilder.Empty(hookData, ...)
	return hookData.Orignal(...)
end

function DispatchBuilder:UpdateDispatcher(hookData)
	hookData.Dispatcher = self:CreateDispatcher(hookData, hookData.Class)
end

function DispatchBuilder:CreateDispatcher(hookData, isClassFunction)

	if(#hookData == 1 and not hookData.Raw and not hookData.Post) then
		return self.SingleNormal
	end

	if(#hookData == 0) then
		if(hookData.Raw and #hookData.Raw == 1 and not hookData.Post) then
			if(isClassFunction) then
				return self.SingleClassRaw
			end
		elseif(hookData.Post and #hookData.Post == 1 and not hookData.Raw) then
			return self.SinglePost
		else
			return self.Empty
		end
	end

	if(IsClassFunction) then
		return DispatchBuilder.MultiHookClassDispatcher
	else
		return DispatchBuilder.MultiHookDispatcher
	end
end

local function CreateRawTableChain(tableCount, IsClass)

	local str = {}
	local FormatString = (IsClass and "tbl[%i](self,") or "tbl[%i]("

	for z=tableCount,1,-1 do
		str[#str+1] = string.format(FormatString, i)
	end

	str[#str+1] = "..."

	for z=1,tableCount do
		str[#str+1] = ")"
	end

	return table.concat(str, "")
end

local function CreateTblPassingString(entryCoount)

	local str = {}

	for z=entryCoount,1,-1 do
		str[#str+1] = string.format("tbl[%i](...) ", i)
	end

	return table.concat(str, "")
end

local function RawArgsToNormalHooks(hookData, ...)
	if(#hookData) then
		for _,hook in ipairs(hookData) do
			hook(...)
		end
	end

	return ...
end

--TODO add exception handling 
function DispatchBuilder.MultiHookClassDispatcher(hookData, ...)

	local retvalue

	if(hookData.Raw) then
		retvalue = hookData.Orignal(RawArgsToNormalHooks(hookData, select(1, ...), RawClassDispatcherI[#hookData.Raw](...)))
	else
		RawArgsToNormalHooks(hookData,...)
		retvalue = hookData.Orignal(...)
	end

	if(hookData.Post) then
	 hookData.ReturnValue = hookData.ReturnValue or retvalue 

		for _,hook in ipairs(hookData.Post) do
			hook(...)
		end
	end

	if(hookData.ReturnValue) then
		retvalue = hookData.ReturnValue
		hookData.ReturnValue = nil
			
		if(retvalue == FakeNil) then
			retvalue = nil
		end
	end
	
 return retvalue
end

function DispatchBuilder.MultiHookDispatcher(hookData, ...)

	local retvalue

	if(hookData.Raw) then
		retvalue = hookData.Orignal(RawArgsToNormalHooks(hookData, RawDispatcherI[#hookData.Raw](...)))
	else
		RawArgsToNormalHooks(hookData, ...)
		retvalue = hookData.Orignal(...)
	end

	if(hookData.Post) then
		hookData.ReturnValue = hookData.ReturnValue or retvalue 

		for _,hook in ipairs(hookData.Post) do
			hook(...)
		end
	end

	if(hookData.ReturnValue) then
		retvalue = hookData.ReturnValue
		hookData.ReturnValue = nil
			
		if(retvalue == FakeNil) then
			retvalue = nil
		end
	end
	
 return retvalue
end

function DispatchBuilder.ErrorHandler(err)
	Shared.Message(err)
end

--note luaJITs xpcall can take extra arguments to pass to the function being called
function DispatchBuilder.DebugDispatcher(hookData, ...)

	local args = {...}
	local success

	if(hookData.Raw) then
		local self = select(1, ...)
		
		for _,hook in ipairs(hookData.Raw) do
			local args2 = {xpcall(hook, DispatchBuilder.ErrorHandler, unpack(args))}
			
			--check to see if the captured success return value is true
			if(args2[1] == true) then
				args2[1] = self
				args = args2
			end
		end
	end

	if(#hookData ~= 0) then
		for _,hook in ipairs(hookData) do
			xpcall(hook, DispatchBuilder.ErrorHandler, unpack(args))
		end
	end
	
	hookData.ReturnValue = hookData.Orignal(unpack(args))
	
	if(hookData.Post) then
		for _,hook in ipairs(hookData.Post) do
			xpcall(hook, DispatchBuilder.ErrorHandler, unpack(args))
		end
	end
	
	local retvalue = hookData.ReturnValue
	hookData.ReturnValue = nil
	
	if(retvalue == FakeNil) then
		retvalue = nil
	end
	
	return retvalue
end

function CreateCustom(hookData)
	
	local funcbody = {[[
		local normalDispatcher = DispatcherI[#hookData]
			return function(hookDataArg, ...)
	]]}

	if(hookData.Raw and #hookData) then
		funcbody[#funcbody+1] = [[
				local tbl = hookDataArg.Raw
		]]
		

		funcbody[#funcbody+1] = [[local retvalue = hookDataArg.Orignal(normalDispatcher(hookDataArg, ]]

		funcbody[#funcbody+1] = CreateRawTableChain(#hookData.Raw)
		funcbody[#funcbody+1] = "))\n"
	else
		if(#hookData) then
			--funcbody[#funcbody+1] = CreateTblPassingString(#hookData)
			
			funcbody[#funcbody+1] = [[
				for _,hook in ipairs(hookData) do
					hook(...)
				end
			]]
		elseif(hookData.Raw) then
			funcbody[#funcbody+1] = [[
				local tbl = hookData.Raw
			]]
			funcbody[#funcbody+1] = CreateRawTableChain(#hookData.Raw)
			funcbody[#funcbody+1] = ")\n"
		end
	end
	
	if(hookData.Post) then
		funcbody[#funcbody+1] = [[
			for _,hook in ipairs(hookDataArg.Post) do
				hook(...)
			end
		]]
	end
	
	funcbody[#funcbody+1] = [[
		if(hookDataArg.ReturnValue) then
			retvalue = hookDataArg.ReturnValue
			hookDataArg.ReturnValue = nil
			
			if(retvalue == FakeNil) then
				retvalue = nil
			end
		end
	
	 return retvalue
	end
	]]
end


local RawClassDispatcherI = {
	[0] = function(...) return ... end,
	function (tbl, self, ...) return tbl[1](self, ...) end,
	function (tbl, self, ...) return tbl[2](self, tbl[1](self, ...)) end,
	function (tbl, self, ...) return tbl[3](self, tbl[2](self, tbl[1](self, ...))) end,
}

setmetatable(RawClassDispatcherI, {
	__index = function(self, i)
		local func = loadstring("return function (tbl, self, ...) return " .. CreateRawTblPassingString(i, true).."end")()
		 rawset(self, i, func)
		
		return func
	end
})

local RawDispatcherI = {
	[0] = function(...) return ... end,
	function (tbl, self, ...) return tbl[1](self, ...) end,
	function (tbl, self, ...) return tbl[2](self, tbl[1](self, ...)) end,
	function (tbl, self, ...) return tbl[3](self, tbl[2](self, tbl[1](self, ...))) end,
}

setmetatable(RawDispatcherI, {
	__index = function(self, i)
		local func = loadstring("return function (tbl, ...) return " .. CreateRawTblPassingString(i).."end")()
		 rawset(self, i, func)
		
		return func
	end
})