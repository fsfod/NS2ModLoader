
if(SavedVariables and type(SavedVariables) == "userdata") then
  //a native SavedVariables loaded from a lua dll module has already been loaded so do nothing
  return
end

local basePath = "config://SavedVariables/"

SavedVariables = {}

local InstanceMT = {__index = SavedVariables}

local function CreatedInstance(self, name, fieldList, container)
  
  assert(type(name) == "string")
  assert(type(fieldList) == "table")
  
  local instance = {
    Name = name,
    Container = container,
    FieldList = fieldList,
    AutoSave = true,
  }
  
  setmetatable(instance, InstanceMT)

  return instance  
end

setmetatable(SavedVariables, {
  __call = CreatedInstance
})

local BaseTable = {
  ["Vector"] = Vector,
  ["Color"] = Color,
}

local LoadMT = {
  __index = BaseTable
}

local LoadScope = setmetatable({}, LoadMT)

function SavedVariables:Load()
  

  local filePath = self:GetFilePath()
  
  local file, openMsg, handle = io.open(filePath, "r")
  
  if(not file) then
    if(string.find(openMsg, "No error")) then
        self.FirstLoad = true
      return true
    end
  
    self.LoadError = true
    RawPrint("Failed to open SavedVariables:", filePath)
   
   return false
  end
  
  if(handle == 0) then
    //io.close(file)

  end
  
  local fileData = file:read("*a")
  
  file:close()
  
  local chunk, msg = loadstring(fileData, filePath)
  
  if(msg) then
    RawPrint("Error while parsing SavedVariables:%s/n%s", filePath, msg)
    self.LoadError = true
   return false
  end
  
  local Container = self.Container
  
  LoadMT.__newindex = function(_, key, value)
    Container[key] = value
  end
  
  setfenv(chunk, LoadScope)
  
  local sucess, errorMsg = pcall(chunk)
  
  if(errorMsg) then
    RawPrint("Error while loading SavedVariables:%s/n%s", filePath, errorMsg)
    self.LoadError = true  
   return false
  end
  
  self.LoadError = false
  
  return true
end

function SavedVariables:GetFilePath()
  return basePath..self.Name..".lua"
end

local indentNum = 0
local IndentLookup = {}

setmetatable(IndentLookup, {__index = function(self, count)
  
  local indent = string.rep("\t", count)
  
  rawset(self, count, indent)
  
  return indent
end})

local function WriteValue(file, val)

  local valueType = type(val)
  
  if(valueType == "string") then
  
    file:write("\"", val, "\",\n")
    
  elseif(valueType == "number" or valueType == "boolean") then
    
    file:write(tostring(val), ",\n")
    
  elseif(valueType == "table") then
    
    file:write(key, "{\n")
     WriteTable(file, val)
    file:write(key, "},\n")
    
  elseif(valueType == "userdata") then
    
    
    if(val:isa("Vector")) then
      file:write(string.format("Vector(%f, %f, %f),\n", val.x, val.y, vla.z))
    elseif(val:isa("Color")) then
      file:write(string.format("Color(%f, %f, %f, %f),\n", val.r, val.g, val.b, val.a))
    end
  end
end

local function WriteArray(file, tbl)
  
  local i = 1
  
  local indent = IndentLookup[indentNum]
  
  repeat
    local val = tbl[i]
    local valueType = type(val)
    
    if(valueType == "string") then
    
      file:write(indent, "\"", val, "\",\n")
      
    elseif(valueType == "number" or valueType == "boolean") then
      
      file:write(indent, "\"", tostring(val), "\",\n")
      
    elseif(valueType == "table") then
      
      file:write(indent, key, "{\n")
       WriteTable(file, val)
      file:write(indent, key, "},\n")
      
    elseif(valueType == "userdata") then
      
      
      if(val:isa("Vector")) then
        file:write(indent, string.format("Vector(%f, %f, %f),\n", val.x, val.y, vla.z))
      elseif(val:isa("Color")) then
        file:write(indent, string.format("Color(%f, %f, %f, %f),\n", val.r, val.g, val.b, val.a))
      end
    end
    
    i = i+1
  until tbl[i] == nil

  return i
end

function WriteTable(file, tbl)
  
  indentNum = indentNum+1
  
  local indent = IndentLookup[indentNum]
  
  local hasArray = false
  
  if(tbl[1]) then
    hasArray = WriteArray(file, tbl)
  end
  
  
  
  for key, val in pairs(tbl) do

    local keyType = type(key)
    
    if(keyType == "number") then
      
      if(key == 1) then
        break
      end
      
      //we have to use brackets for hastable keys that are numbers
      key = string.format("[%i]", key)
    elseif(keyType == "string") then
      key = string.format("[\"%s\"]", key)
    else
      key = "-- Skipping unsupported key type "..keyType
    end
    

    local valueType = type(val)
    
    if(valueType == "string") then
    
      file:write(indent, key, " = \"", val, "\",\n")
      
    elseif(valueType == "number" or valueType == "boolean") then
      
      file:write(indent, key, " = ", tostring(val), ",\n")
      
    elseif(valueType == "table") then
      
      file:write(indent, key, " = {\n")
       WriteTable(file, val)
      file:write(indent, key, "},\n")
      
    elseif(valueType == "userdata") then
      
      if(val:isa("Vector")) then
        file:write(indent, key, string.format(" = Vector(%f, %f, %f),\n", val.x, val.y, vla.z))
      elseif(val:isa("Color")) then
        file:write(indent, key, string.format(" = Color(%f, %f, %f, %f),\n", val.r, val.g, val.b, val.a))
      end
      
    else
      file:write("--Skipping unsupported value type "..valueType)
    end

  end
  
  indentNum = indentNum-1
end
  

function SavedVariables:Save()  
  local filePath = self:GetFilePath()
  
  local file, msg = io.open(filePath, "w+")
  
  if(not file) then
    //note if something else has opened our file with no write sharing we got a not found error message
    RawPrint("SavedVariables:Save Failed to open :", msg)
   return false
  end
  
  indentNum = 0
  
  for _,fieldName in ipairs(self.FieldList) do
    
    local value = self.Container[fieldName]
    local valType = type(value)

    if(type(value) == "table") then
      file:write(fieldName, " = {\n")
        WriteTable(file, value)
      file:write("}\n")
    elseif(value ~= nil) then
      file:write(fieldName, " = ", "\n")
      WriteValue(file, value)
    end
    
  end
  
  file:flush()
  file:close()
end